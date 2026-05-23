# Reference (Go Functions)

`Initialize` から呼ぶ最小構成の関数例。

```go
package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"strconv"
	"time"
)

const defaultBenchEndDelaySec = 60

func benchNotifyEnabled() bool {
	v := strings.ToLower(strings.TrimSpace(os.Getenv("BENCH_NOTIFY_ENABLED")))
	switch v {
	case "":
		return true
	case "false", "0", "off", "no":
		return false
	default:
		return true
	}
}

func benchEndDelaySec() int {
	v := os.Getenv("BENCH_END_NOTIFY_AFTER_SEC")
	if v == "" {
		return defaultBenchEndDelaySec
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return defaultBenchEndDelaySec
	}
	return n
}

func notifySlackAfter(delaySec int, text string) {
	time.Sleep(time.Duration(delaySec) * time.Second)
	notifySlack(text)
}

func notifySlack(text string) {
	webhook := os.Getenv("SLACK_WEBHOOK_URL")
	if webhook == "" {
		log.Printf("skip slack notify: SLACK_WEBHOOK_URL is empty")
		return
	}

	body, err := json.Marshal(map[string]string{"text": text})
	if err != nil {
		log.Printf("slack payload marshal failed: %v", err)
		return
	}

	req, err := http.NewRequest(http.MethodPost, webhook, bytes.NewBuffer(body))
	if err != nil {
		log.Printf("slack request build failed: %v", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("slack request failed: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		log.Printf("slack request returned non-2xx: %d", resp.StatusCode)
	}
}

func notifyBenchStartAndEndHint() {
	if !benchNotifyEnabled() {
		log.Printf("skip slack notify: BENCH_NOTIFY_ENABLED is false")
		return
	}

	host := os.Getenv("HOSTNAME")
	now := time.Now().Format(time.RFC3339)
	delaySec := benchEndDelaySec()

	go notifySlack("[BENCH_START] access detected at " + now + " host=" + host)
	go notifySlackAfter(
		delaySec,
		"[BENCH_END_HINT] "+strconv.Itoa(delaySec)+"s passed since access host="+host,
	)
}
```

`Initialize` 側では以下を追加する:

```go
func Initialize(...) {
	notifyBenchStartAndEndHint()
	// existing logic...
}
```
