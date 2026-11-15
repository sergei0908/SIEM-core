# Датасеты

Каталог открытых наборов данных для SIEM: корреляция алертов, нормализация логов,
проверка Sigma-правил и нагрузочные тесты. Проверено 11.11.2026.

Сами данные в репозиторий **не кладём** (файлы до 130 ГБ, у GitHub лимит 100 МБ на файл).
Скачанное складывается в `datasets/raw/`, эта папка в `.gitignore`.

## Быстрый старт

```bash
python datasets/download_ait_ads.py
```

Скрипт скачает AIT-ADS (96 МБ) с Zenodo в `datasets/raw/ait_ads/` и сверит контрольные суммы md5.
Нужен только Python 3, внешних библиотек нет.

## Каталог

Приоритет: **1** — используем сейчас, **2** — позже, **3** — только для обзора.

| Датасет | Размер | Источники | Разметка | Лицензия | Для чего | Приор. |
|---|---|---|---|---|---|---|
| [AIT Alert Data Set (AIT-ADS)](https://zenodo.org/records/8263181) | 96 МБ zip (2,86 ГБ распакованный), 2 655 821 алерт | Wazuh, Suricata, AMiner; 8 сценариев атак | `labels.csv`: начало и конец каждой фазы атаки | CC BY 4.0 | корреляция алертов и метрики, основной набор | 1 |
| [LANL Comprehensive Multi-Source](https://csr.lanl.gov/data/cyber1/) | ~11 ГБ gzip, ~1,65 млрд событий за 58 дней | аутентификация, процессы, сетевые потоки, DNS | `redteam.txt` — события компрометации | CC0 1.0 | нагрузочные тесты на большом объёме, второй набор с разметкой | 1–2 |
| [AIT Log Data Set V2.0](https://zenodo.org/records/5789064) | 130,6 ГБ (8 архивов по 7–27 ГБ) | сырые логи тех же 8 сценариев: apache, auth, dns, vpn, audit и др. | построчная: номер строки + метки | CC BY-NC-SA 4.0 | прогон всего конвейера; брать один сценарий (russellmitchell, 7,1 ГБ) | 2 |
| [OTRF Security-Datasets (Mordor)](https://github.com/OTRF/Security-Datasets) | от КБ до МБ на запись | Windows (Security, Sysmon, PowerShell), AWS | по технике MITRE ATT&CK | в репозитории указаны и GPL-3.0, и MIT — проверить LICENSE | нормализация Windows, проверка Sigma | 2 |
| [EVTX-ATTACK-SAMPLES](https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES) | 200+ файлов .evtx | журналы Windows | по папкам-тактикам ATT&CK | GPL-3.0 | тесты Sigma-движка | 2 |
| [Loghub](https://github.com/logpai/loghub) | от 2 МБ до 30 ГБ на набор | Linux, Windows, OpenSSH, HDFS, Apache и др. | только у части наборов, и это сбои систем, а не атаки | свободно для исследований, цитировать статью Loghub | фоновая нагрузка, парсинг | 3 |
| [Splunk BOTS v3](https://github.com/splunk/botsv3) | 320 МБ | AWS, Azure AD, O365, Windows, Sysmon, osquery, Cisco ASA и др. | явной нет (вопросы CTF) | CC0 1.0 | многоисточниковая картина с облаками; нужен Splunk | 3 |
| [CIC-IDS2017](https://www.unb.ca/cic/datasets/ids-2017.html) | ~51 ГБ (PCAP + CSV) | сетевой трафик | каждый поток помечен типом атаки | открыт для исследований, цитировать Sharafaldin et al. 2018 | сетевая часть; это потоки, а не алерты | 3 |
| CSE-CIC-IDS2018 | ~450 ГБ (AWS Open Data) | сетевой трафик + логи машин | как в 2017 | как в 2017 | только упомянуть | 3 |

## Как скачать остальные

- **LANL** — на странице набора нужно указать email и цель использования, после этого дают ссылки.
- **AIT Log V2** — архивы по сценариям на Zenodo, без регистрации.
- **Mordor, EVTX-ATTACK-SAMPLES, Loghub, BOTS v3** — через GitHub-репозитории по ссылкам в таблице.
- **CIC-IDS2017** — ссылка «Download this dataset» на странице UNB.

## AIT-ADS: формат

В `ait_ads.zip` 16 файлов, по два на каждый из 8 сценариев (fox, harrison, russellmitchell,
santos, shaw, wardbeck, wheeler, wilson). Формат JSON Lines: одна строка — один алерт.

- `<сценарий>_wazuh.json` — алерты Wazuh и Suricata (у Suricata `location` = `/var/log/suricata/...`).
- `<сценарий>_aminer.json` — алерты AMiner.

| Что | Wazuh / Suricata | AMiner |
|---|---|---|
| время | `@timestamp` (ISO 8601) | `LogData.Timestamps[0]` (Unix) |
| что сработало | `rule.description`; у Suricata — `data.alert.signature` | `AnalysisComponent.AnalysisComponentName` |
| хост | `predecoder.hostname` (есть у ~37 %) | `AMiner.ID` (IP машины) |
| IP источника | `data.src_ip` (Suricata), `data.srcip` (Wazuh) | первый адрес в строке веб-лога |
| IP назначения | `data.dest_ip` (Suricata), `data.dstip` (Wazuh) | — |
| лог-файл | `location` | `LogData.LogResources[0]` |

`labels.csv` — колонки `scenario, attack, start, end` (Unix-время). Фазы: network_scans,
service_scans, wpscan, dirb, webshell, cracking, reverse_shell, privilege_escalation,
service_stop, dnsteal.

Что важно знать:
- **96 % алертов в фазах атаки — шаг dirb** (перебор адресов сайта, ~1,69 млн алертов «Web server 400 error code»). Метрики по всем алертам в основном отражают его.
- Разметка по интервалам времени, поэтому фоновые алерты внутри интервала тоже получают метку атаки.
- Есть дубликаты: одна строка лога попадает в два файла (`mail.log` / `mail.info`, `syslog`), около 7 %. Suricata пишет каждое срабатывание и в `eve.json`, и в `fast.log`.

Цитирование: Landauer M., Skopik F., Wurzenberger M. Introducing a New Alert Data Set for
Multi-Step Attack Analysis. CSET 2024. https://doi.org/10.1145/3675741.3675748
