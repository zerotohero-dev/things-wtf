# 18 · Testing

Testing operators has three layers. The lower you test, the faster and more
reliable your feedback loop. Build all three.

| Layer | Tool | What it tests | Speed |
|---|---|---|---|
| Unit | `fake.NewClientBuilder` | Reconciler logic, output objects | ~milliseconds |
| Integration | `envtest` | CRD, RBAC, admission webhooks, controller | ~seconds |
| End-to-end | Real cluster | Full user workflow | ~minutes |

---

## Unit testing with the fake client

Your reconciler is a plain Go function. Test it by constructing a fake client
pre-populated with objects:

```go
func TestReconcile_HappyPath(t *testing.T) {
    sc := &spikev1alpha1.SpikeConfig{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test",
            Namespace: "default",
        },
        Spec: spikev1alpha1.SpikeConfigSpec{
            WorkloadId: "spiffe://test/workload",
        },
    }

    // fake.NewClientBuilder creates an in-memory client.
    // Prepopulate it with the objects your reconciler expects to find.
    fakeClient := fake.NewClientBuilder().
        WithScheme(scheme).
        WithObjects(sc).
        WithStatusSubresource(sc).  // enables fake /status writes
        Build()

    // Inject a mock for any external clients your reconciler uses.
    r := &SpikeConfigReconciler{
        Client: fakeClient,
        Scheme: scheme,
        // SPIREClient: &mockSPIREClient{expiryOffset: 24 * time.Hour},
    }

    result, err := r.Reconcile(context.Background(), ctrl.Request{
        NamespacedName: types.NamespacedName{Name: "test", Namespace: "default"},
    })

    require.NoError(t, err)
    assert.Greater(t, result.RequeueAfter, time.Duration(0))

    // Verify the Secret was created
    var secret corev1.Secret
    err = fakeClient.Get(context.Background(),
        types.NamespacedName{Name: "test-svid", Namespace: "default"}, &secret)
    require.NoError(t, err)
    assert.Contains(t, secret.Data, "cert.pem")

    // Verify status was updated correctly
    var updated spikev1alpha1.SpikeConfig
    err = fakeClient.Get(context.Background(),
        types.NamespacedName{Name: "test", Namespace: "default"}, &updated)
    require.NoError(t, err)
    assert.Equal(t, "Ready", updated.Status.Phase)
    assert.Equal(t, sc.Generation, updated.Status.ObservedGeneration)
}

func TestReconcile_NotFound(t *testing.T) {
    // If the object doesn't exist, reconcile should return nil, nil.
    fakeClient := fake.NewClientBuilder().WithScheme(scheme).Build()
    r := &SpikeConfigReconciler{Client: fakeClient, Scheme: scheme}

    result, err := r.Reconcile(context.Background(), ctrl.Request{
        NamespacedName: types.NamespacedName{Name: "gone", Namespace: "default"},
    })

    require.NoError(t, err)
    assert.Equal(t, ctrl.Result{}, result)
}
```

---

## Integration testing with envtest

`envtest` starts a real API server and etcd as lightweight binaries, running
your controller against them. This tests your CRD schema, RBAC, admission webhooks,
and controller logic end-to-end without a real cluster.

### Suite setup (Ginkgo + Gomega)

```go
// internal/controller/suite_test.go

var (
    cfg        *rest.Config
    k8sClient  client.Client
    testEnv    *envtest.Environment
    ctx        context.Context
    cancel     context.CancelFunc
)

var _ = BeforeSuite(func() {
    logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))
    ctx, cancel = context.WithCancel(context.TODO())

    testEnv = &envtest.Environment{
        // Point at your generated CRD YAML
        CRDDirectoryPaths:     []string{filepath.Join("..", "..", "config", "crd", "bases")},
        ErrorIfCRDPathMissing: true,
    }

    var err error
    cfg, err = testEnv.Start()
    Expect(err).NotTo(HaveOccurred())

    err = spikev1alpha1.AddToScheme(scheme)
    Expect(err).NotTo(HaveOccurred())

    k8sClient, err = client.New(cfg, client.Options{Scheme: scheme})
    Expect(err).NotTo(HaveOccurred())

    mgr, err := ctrl.NewManager(cfg, ctrl.Options{Scheme: scheme})
    Expect(err).NotTo(HaveOccurred())

    err = (&SpikeConfigReconciler{
        Client: mgr.GetClient(),
        Scheme: mgr.GetScheme(),
    }).SetupWithManager(mgr)
    Expect(err).NotTo(HaveOccurred())

    go func() {
        defer GinkgoRecover()
        err = mgr.Start(ctx)
        Expect(err).NotTo(HaveOccurred())
    }()
})

var _ = AfterSuite(func() {
    cancel()
    err := testEnv.Stop()
    Expect(err).NotTo(HaveOccurred())
})
```

### Writing a controller integration test

```go
var _ = Describe("SpikeConfig controller", func() {
    const timeout  = time.Second * 30
    const interval = time.Millisecond * 250

    Context("when a SpikeConfig is created", func() {
        It("should provision the SVID and reach Ready phase", func() {
            sc := &spikev1alpha1.SpikeConfig{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-config",
                    Namespace: "default",
                },
                Spec: spikev1alpha1.SpikeConfigSpec{
                    WorkloadId: "spiffe://test/workload",
                },
            }
            Expect(k8sClient.Create(ctx, sc)).To(Succeed())

            // Wait for the controller to reconcile
            Eventually(func() string {
                k8sClient.Get(ctx, client.ObjectKeyFromObject(sc), sc)
                return sc.Status.Phase
            }, timeout, interval).Should(Equal("Ready"))

            // Verify the Secret was created
            secret := &corev1.Secret{}
            Eventually(func() error {
                return k8sClient.Get(ctx,
                    types.NamespacedName{Name: sc.Name + "-svid", Namespace: sc.Namespace},
                    secret)
            }, timeout, interval).Should(Succeed())

            Expect(secret.Data).To(HaveKey("cert.pem"))
        })
    })
})
```

!!! info "Getting envtest binaries"

    Run `make envtest` (kubebuilder generates this target). It uses the
    `setup-envtest` tool to download `kube-apiserver` and `etcd` binaries into
    `bin/`. Pin the Kubernetes version in your Makefile:

    ```makefile
    ENVTEST_K8S_VERSION = 1.29.0
    ```

---

## Testing checklist

- [ ] Happy path: object created, reaches Ready, owned resources exist
- [ ] Not found: reconcile for a deleted object returns `nil, nil`
- [ ] External failure: mock external client returns error, status reflects failure
- [ ] Deletion: finalizer cleanup runs, object is eventually deleted
- [ ] Idempotency: running reconcile twice produces the same outcome
- [ ] Immutability: webhook rejects `workloadId` changes on update
- [ ] Defaulting: webhook injects expected defaults on create
