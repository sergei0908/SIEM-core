import argparse
import json
import random
import time
from datetime import datetime, timezone

import httpx

HOSTS = [f"host-{x}" for x in range(1, 51)]
LEVELS = ["INFO", "WARN", "ERROR"]
LEVEL_WEIGHTS = [85, 10, 5]
REQUEST_TIMEOUT = 5.0
REPORT_INTERVAL = 1.0


def make_event():
    now = datetime.now(timezone.utc)
    ts = now.isoformat(timespec="milliseconds").replace("+00:00", "Z")
    return {
        "ts": ts,
        "host": random.choice(HOSTS),
        "level": random.choices(LEVELS, weights=LEVEL_WEIGHTS)[0],
        "source": "generator",
        "message": "generator event",
    }


def parse_args():
    parser = argparse.ArgumentParser(description="Load generator for SIEM pipeline")
    parser.add_argument("--eps", type=float, required=True, help="target events per second")
    parser.add_argument("--url", default="http://localhost:8080")
    parser.add_argument("--duration", type=float, default=10, help="test duration in seconds")
    parser.add_argument("--tick", type=float, default=0.1, help="tick length in seconds")
    return parser.parse_args()


def main():
    args = parse_args()
    events_per_tick = args.eps * args.tick

    with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
        start = time.perf_counter()
        end = start + args.duration
        next_tick = start

        carry = 0.0              # накопленный "долг" событий, включая дробную часть
        sent_total = 0
        late_ticks = 0

        last_report = start
        sent_since_report = 0
        max_post_time = 0.0      # самый долгий POST за интервал отчёта

        while time.perf_counter() < end:
            carry += events_per_tick
            batch_size = int(carry)
            carry -= batch_size

            if batch_size > 0:
                body = "\n".join(json.dumps(make_event()) for _ in range(batch_size))
                post_start = time.perf_counter()
                response = client.post(
                    args.url,
                    content=body,
                    headers={"Content-Type": "application/x-ndjson"},
                )
                response.raise_for_status()
                max_post_time = max(max_post_time, time.perf_counter() - post_start)

                sent_total += batch_size
                sent_since_report += batch_size

            now = time.perf_counter()
            interval = now - last_report
            if interval >= REPORT_INTERVAL:
                actual_eps = sent_since_report / interval
                print(
                    f"t={now - start:6.1f}s  target={args.eps:8.0f}  "
                    f"actual={actual_eps:8.0f}  late_ticks={late_ticks}  "
                    f"max_post={max_post_time * 1000:6.1f}ms"
                )
                last_report = now
                sent_since_report = 0
                max_post_time = 0.0

            next_tick += args.tick
            delay = next_tick - time.perf_counter()
            if delay > 0:
                time.sleep(delay)
            else:
                late_ticks += 1

        elapsed = time.perf_counter() - start

    print(
        f"\nTOTAL: sent={sent_total}  elapsed={elapsed:.2f}s  "
        f"avg_eps={sent_total / elapsed:.0f}  late_ticks={late_ticks}"
    )


if __name__ == "__main__":
    main()