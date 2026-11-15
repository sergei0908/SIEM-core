CREATE DATABASE IF NOT EXISTS siem;

CREATE TABLE IF NOT EXISTS siem.logs
(
    ts           DateTime64(3),
    inserted_at  DateTime64(3) DEFAULT now64(3),
    host         LowCardinality(String),
    level        LowCardinality(String),
    source       LowCardinality(String),
    message      String
)
ENGINE = MergeTree
ORDER BY (host, ts);