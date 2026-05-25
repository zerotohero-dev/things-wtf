# Testing with envtest

`envtest` (from `sigs.k8s.io/controller-runtime/pkg/envtest`) spins up a real API server and etcd process — no kubelet, no scheduler — so you can test your controller against real Kubernetes API semantics: real validation, real RBAC, real watch streams, real CRD schemas.

This is the gold standard for operator testing. Unit tests with mocked clients miss too many edge cases (CRD validation, watch semantics, optimistic locking). `envtest` catches those.

---

## Setup: Download the Binaries

```bash
# Download API server + etcd binaries for envtest
make envtest

# This sets KUBEBUILDER_ASSETS to the binary path.
# The envtest suite reads this env var automatically.
```

---

## Suite Setup

```go title="internal/controller/suite_test.go"
package controller_test

import (
    "context"
    "path/filepath"
    "testing"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"

    appsv1       "k8s.io/api/apps/v1"
    corev1       "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/runtime"
    clientgoscheme "k8s.io/client-go/kubernetes/scheme"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/envtest"
    logf "sigs.k8s.io/controller-runtime/pkg/log"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"

    appsv1alpha1 "github.com/yourorg/webapp-operator/api/v1alpha1"
    "github.com/yourorg/webapp-operator/internal/controller"
)

var (
    cfg       *rest.Config
    k8sClient client.Client
    testEnv   *envtest.Environment
    scheme    *runtime.Scheme
    ctx       context.Context
    cancel    context.CancelFunc
)

func TestControllers(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Controller Suite")
}

var _ = BeforeSuite(func() {
    logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))
    ctx, cancel = context.WithCancel(context.Background())

    By("bootstrapping test environment")
    testEnv = &envtest.Environment{
        // Point at the generated CRD YAML files
        CRDDirectoryPaths:     []string{filepath.Join("..", "..", "config", "crd", "bases")},
        ErrorIfCRDPathMissing: true,
        // BinaryAssetsDirectory is set by KUBEBUILDER_ASSETS env var
        // Run `make envtest` to download and set it.
    }

    scheme = runtime.NewScheme()
    Expect(clientgoscheme.AddToScheme(scheme)).To(Succeed())
    Expect(appsv1alpha1.AddToScheme(scheme)).To(Succeed())

    var err error
    cfg, err = testEnv.Start()
    Expect(err).NotTo(HaveOccurred())
    Expect(cfg).NotTo(BeNil())

    k8sClient, err = client.New(cfg, client.Options{Scheme: scheme})
    Expect(err).NotTo(HaveOccurred())

    // Start the manager with the controller under test
    mgr, err := ctrl.NewManager(cfg, ctrl.Options{
        Scheme: scheme,
        // Disable metrics and health probe binding for tests
        Metrics:                metricsserver.Options{BindAddress: "0"},
        HealthProbeBindAddress: "0",
        // No leader election in tests
        LeaderElection: false,
    })
    Expect(err).NotTo(HaveOccurred())

    err = (&controller.WebAppReconciler{
        Client:   mgr.GetClient(),
        Scheme:   mgr.GetScheme(),
        Recorder: mgr.GetEventRecorderFor("webapp-controller"),
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
    By("tearing down the test environment")
    Expect(testEnv.Stop()).To(Succeed())
})
```

---

## Controller Tests

```go title="internal/controller/webapp_controller_test.go"
package controller_test

import (
    "time"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"

    appsv1        "k8s.io/api/apps/v1"
    corev1        "k8s.io/api/core/v1"
    networkingv1  "k8s.io/api/networking/v1"
    apierrors     "k8s.io/apimachinery/pkg/api/errors"
    metav1        "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/types"

    appsv1alpha1 "github.com/yourorg/webapp-operator/api/v1alpha1"
)

const (
    timeout  = 10 * time.Second
    interval = 250 * time.Millisecond
)

var _ = Describe("WebApp controller", func() {

    Context("When creating a WebApp", func() {
        const (
            name      = "test-webapp"
            namespace = "default"
        )

        AfterEach(func() {
            // Clean up between tests
            webapp := &appsv1alpha1.WebApp{}
            if err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp); err == nil {
                Expect(k8sClient.Delete(ctx, webapp)).To(Succeed())
                Eventually(func() bool {
                    err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp)
                    return apierrors.IsNotFound(err)
                }, timeout, interval).Should(BeTrue(), "WebApp should be fully deleted")
            }
        })

        It("should create a Deployment with correct spec", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      name,
                    Namespace: namespace,
                },
                Spec: appsv1alpha1.WebAppSpec{
                    Image:    "nginx:1.25",
                    Replicas: 2,
                    Port:     80,
                },
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            dep := &appsv1.Deployment{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{
                    Namespace: namespace, Name: name,
                }, dep)
            }, timeout, interval).Should(Succeed(), "Deployment should be created")

            Expect(*dep.Spec.Replicas).To(Equal(int32(2)))
            Expect(dep.Spec.Template.Spec.Containers).To(HaveLen(1))
            Expect(dep.Spec.Template.Spec.Containers[0].Image).To(Equal("nginx:1.25"))
            Expect(dep.Spec.Template.Spec.Containers[0].Ports[0].ContainerPort).To(Equal(int32(80)))
        })

        It("should create a Service", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec:       appsv1alpha1.WebAppSpec{Image: "nginx:1.25", Replicas: 1, Port: 8080},
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            svc := &corev1.Service{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{
                    Namespace: namespace, Name: name,
                }, svc)
            }, timeout, interval).Should(Succeed())

            Expect(svc.Spec.Ports[0].TargetPort.IntVal).To(Equal(int32(8080)))
            Expect(svc.Spec.Selector["app.kubernetes.io/name"]).To(Equal(name))
        })

        It("should create an Ingress when spec.ingress is set", func() {
            host := "test-app.example.com"
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec: appsv1alpha1.WebAppSpec{
                    Image:    "nginx:1.25",
                    Replicas: 1,
                    Port:     80,
                    Ingress:  &appsv1alpha1.IngressSpec{Host: host},
                },
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            ingress := &networkingv1.Ingress{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{
                    Namespace: namespace, Name: name,
                }, ingress)
            }, timeout, interval).Should(Succeed())

            Expect(ingress.Spec.Rules[0].Host).To(Equal(host))
        })

        It("should set owner references on all owned resources", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec:       appsv1alpha1.WebAppSpec{Image: "nginx:1.25", Replicas: 1, Port: 80},
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            // Fetch owner info
            Expect(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp)).To(Succeed())

            dep := &appsv1.Deployment{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
            }, timeout, interval).Should(Succeed())

            Expect(dep.OwnerReferences).To(HaveLen(1))
            Expect(dep.OwnerReferences[0].Name).To(Equal(name))
            Expect(dep.OwnerReferences[0].Kind).To(Equal("WebApp"))
            Expect(*dep.OwnerReferences[0].Controller).To(BeTrue())
        })

        It("should restore a manually deleted Deployment", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec:       appsv1alpha1.WebAppSpec{Image: "nginx:1.25", Replicas: 1, Port: 80},
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            // Wait for initial creation
            dep := &appsv1.Deployment{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
            }, timeout, interval).Should(Succeed())

            // Delete the Deployment manually (simulate drift / accidental deletion)
            Expect(k8sClient.Delete(ctx, dep)).To(Succeed())

            // Verify it's gone briefly
            Eventually(func() bool {
                err := k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
                return apierrors.IsNotFound(err)
            }, 5*time.Second, interval).Should(BeTrue())

            // Controller should restore it
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
            }, timeout, interval).Should(Succeed(), "Deployment should be recreated after drift")
        })

        It("should update Deployment image when spec.image changes", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec:       appsv1alpha1.WebAppSpec{Image: "nginx:1.24", Replicas: 1, Port: 80},
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            // Wait for deployment with original image
            dep := &appsv1.Deployment{}
            Eventually(func() string {
                k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
                if len(dep.Spec.Template.Spec.Containers) == 0 {
                    return ""
                }
                return dep.Spec.Template.Spec.Containers[0].Image
            }, timeout, interval).Should(Equal("nginx:1.24"))

            // Update spec
            Expect(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp)).To(Succeed())
            webapp.Spec.Image = "nginx:1.25"
            Expect(k8sClient.Update(ctx, webapp)).To(Succeed())

            // Verify Deployment image is updated
            Eventually(func() string {
                k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
                if len(dep.Spec.Template.Spec.Containers) == 0 {
                    return ""
                }
                return dep.Spec.Template.Spec.Containers[0].Image
            }, timeout, interval).Should(Equal("nginx:1.25"), "Deployment image should be updated")
        })

        It("should remove Ingress when spec.ingress is cleared", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec: appsv1alpha1.WebAppSpec{
                    Image:    "nginx:1.25",
                    Replicas: 1,
                    Port:     80,
                    Ingress:  &appsv1alpha1.IngressSpec{Host: "test.example.com"},
                },
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            // Wait for Ingress to exist
            ingress := &networkingv1.Ingress{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, ingress)
            }, timeout, interval).Should(Succeed())

            // Clear ingress from spec
            Expect(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp)).To(Succeed())
            webapp.Spec.Ingress = nil
            Expect(k8sClient.Update(ctx, webapp)).To(Succeed())

            // Ingress should be deleted
            Eventually(func() bool {
                err := k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, ingress)
                return apierrors.IsNotFound(err)
            }, timeout, interval).Should(BeTrue(), "Ingress should be removed when spec.ingress is nil")
        })

        It("should set Available condition in status", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec:       appsv1alpha1.WebAppSpec{Image: "nginx:1.25", Replicas: 1, Port: 80},
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            // Wait for status to be populated with a condition
            Eventually(func() bool {
                Expect(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp)).To(Succeed())
                for _, c := range webapp.Status.Conditions {
                    if c.Type == "Available" {
                        return true
                    }
                }
                return false
            }, timeout, interval).Should(BeTrue(), "WebApp should have Available condition set")
        })

        It("should set ObservedGeneration in status", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec:       appsv1alpha1.WebAppSpec{Image: "nginx:1.25", Replicas: 1, Port: 80},
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            Eventually(func() bool {
                Expect(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, webapp)).To(Succeed())
                return webapp.Status.ObservedGeneration == webapp.Generation
            }, timeout, interval).Should(BeTrue(), "ObservedGeneration should match metadata.generation")
        })

        It("should cascade delete all owned resources when WebApp is deleted", func() {
            webapp := &appsv1alpha1.WebApp{
                ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: namespace},
                Spec: appsv1alpha1.WebAppSpec{
                    Image:    "nginx:1.25",
                    Replicas: 1,
                    Port:     80,
                    Ingress:  &appsv1alpha1.IngressSpec{Host: "cascade-test.example.com"},
                },
            }
            Expect(k8sClient.Create(ctx, webapp)).To(Succeed())

            // Wait for all resources to be created
            Eventually(func() error {
                dep := &appsv1.Deployment{}
                return k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
            }, timeout, interval).Should(Succeed())

            // Delete the WebApp
            Expect(k8sClient.Delete(ctx, webapp)).To(Succeed())

            // All owned resources should be GC'd
            Eventually(func() bool {
                dep := &appsv1.Deployment{}
                svc := &corev1.Service{}
                depErr := k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, dep)
                svcErr := k8sClient.Get(ctx, types.NamespacedName{Namespace: namespace, Name: name}, svc)
                return apierrors.IsNotFound(depErr) && apierrors.IsNotFound(svcErr)
            }, timeout, interval).Should(BeTrue(), "Owned resources should be garbage collected")
        })
    })
})
```

---

## Running the Tests

```bash
# Run with envtest (downloads binaries if needed)
make envtest
KUBEBUILDER_ASSETS="$(./bin/setup-envtest use --bin-path ./bin/k8s/)" \
  go test ./internal/controller/... -v

# Or via make
make test

# Run with race detector (highly recommended)
KUBEBUILDER_ASSETS="..." go test -race ./internal/controller/...

# Run a single test by label
go test ./internal/controller/... -v --label-filter="drift"
```

---

## Testing Anti-Patterns

!!! warning "Don't test implementation details — test behavior"
    Test what the controller *does*, not how. Testing that `reconcileDeployment` was called is fragile. Testing that a Deployment exists with the right spec is robust.

!!! warning "Don't use time.Sleep — use Eventually"
    Controllers are asynchronous. `time.Sleep(1 * time.Second)` is a lie — it works until it doesn't. `Eventually` with a timeout polls until the condition is true, making tests both faster and more reliable.

    ```go
    // WRONG
    time.Sleep(2 * time.Second)
    Expect(k8sClient.Get(ctx, key, dep)).To(Succeed())

    // CORRECT
    Eventually(func() error {
        return k8sClient.Get(ctx, key, dep)
    }, 10*time.Second, 250*time.Millisecond).Should(Succeed())
    ```

!!! warning "Clean up after each test"
    Use `AfterEach` to delete created objects. If tests are not isolated, a leftover object from one test can cause the next test to fail or behave unexpectedly. Use `Eventually` with `IsNotFound` to confirm deletion is complete before the next test runs.

---

## Testing Webhook Validation

If you have validation webhooks, envtest can run them too:

```go
testEnv = &envtest.Environment{
    CRDDirectoryPaths:     []string{...},
    WebhookInstallOptions: envtest.WebhookInstallOptions{
        Paths: []string{filepath.Join("..", "..", "config", "webhook")},
    },
}

// After starting:
mgr, err := ctrl.NewManager(cfg, ctrl.Options{
    WebhookServer: webhook.NewServer(webhook.Options{
        Host:    testEnv.WebhookInstallOptions.LocalServingHost,
        Port:    testEnv.WebhookInstallOptions.LocalServingPort,
        CertDir: testEnv.WebhookInstallOptions.LocalServingCertDir,
    }),
})
// Register webhooks with mgr
```
