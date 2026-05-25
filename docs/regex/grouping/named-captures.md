# Named Captures

Named captures associate a label with a group, making patterns self-documenting and robust against refactoring.

Adding or removing groups won't break code that accesses captures by name instead of index.

---

## Syntax by Language

=== "JavaScript (ES2018+)"

    ```js
    const re = /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/;
    const { groups: { year, month, day } } = "2024-07-04".match(re);
    // year = "2024", month = "07", day = "04"
    ```

=== "Python"

    ```python
    m = re.match(r'(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})', '2024-07-04')
    m.group('year')    # '2024'
    m.groupdict()      # {'year': '2024', 'month': '07', 'day': '04'}
    ```

=== "Go"

    ```go
    re := regexp.MustCompile(`(?P<year>\d{4})-(?P<month>\d{2})`)
    m := re.FindStringSubmatch("2024-07")
    names := re.SubexpNames()
    result := map[string]string{}
    for i, name := range names {
        if i != 0 && name != "" { result[name] = m[i] }
    }
    ```

=== "Java"

    ```java
    Matcher m = Pattern.compile("(?<year>\\d{4})-(?<month>\\d{2})")
                        .matcher("2024-07");
    if (m.find()) {
        m.group("year");    // "2024"
        m.group("month");   // "07"
    }
    ```

=== "PCRE / PHP"

    ```php
    preg_match('/(?P<year>\d{4})-(?P<month>\d{2})/', '2024-07', $m);
    $m['year'];    // '2024'
    $m['month'];   // '07'
    ```

---

## Named Backreferences in Patterns

```regex
# Match a repeated word (JS)
/\b(?<word>\w+)\s+\k<word>\b/gi
# Matches: "the the", "is is"

# Python equivalent
r'\b(?P<word>\w+)\s+(?P=word)\b'

# PCRE
(?<word>\w+)\s+\k<word>
```

---

## Named Captures in Replacements

```js
// JavaScript — named groups in replacement string
"2024-07-04".replace(
  /(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})/,
  '$<d>/$<m>/$<y>'
)
// → "04/07/2024"
```

```python
# Python
re.sub(r'(?P<y>\d{4})-(?P<m>\d{2})-(?P<d>\d{2})',
       r'\g<d>/\g<m>/\g<y>', '2024-07-04')
# → '04/07/2024'
```

---

## When to Use Named vs. Numbered

Use **named captures** when:

- The pattern has more than 2–3 capture groups
- The code will be maintained by others (or future-you)
- You might add/remove groups later
- The group represents a meaningful domain concept (year, port, hostname…)

Use **numbered captures** when:

- Simple one-off replacements (`$1`, `$2`)
- Single-use throwaway patterns
