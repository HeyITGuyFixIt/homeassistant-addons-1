# Planefence Add-on

Track aircraft flying near your ADS-B receiver. Planefence logs low-altitude / nearby aircraft, generates noise statistics, and can send alerts via Discord, Mastodon, or Telegram.

This add-on wraps [docker-planefence](https://github.com/sdr-enthusiasts/docker-planefence) by kx1t / SDR-Enthusiasts.

## Prerequisites

The **ADS-B Multi-Portal Feeder** add-on must be running and exposing port 30003 (BaseStation/SBS output). Planefence reads aircraft data from that port.

## Configuration

| Option             | Default                    | Description                                              |
| ------------------ | -------------------------- | -------------------------------------------------------- |
| `PF_SOCK30003HOST` | `adsb-multi-portal-feeder` | Hostname of your ADS-B feeder add-on                     |
| `PF_SOCK30003PORT` | `30003`                    | SBS output port                                          |
| `PF_LAT`           | HA latitude                | Your station latitude (auto-filled from Home Assistant)  |
| `PF_LON`           | HA longitude               | Your station longitude (auto-filled from Home Assistant) |
| `PF_MAXDIST`       | `50`                       | Maximum distance from station (nautical miles)           |
| `PF_MAXALT`        | `10000`                    | Maximum altitude (feet)                                  |
| `TZ`               | `UTC`                      | Timezone, e.g. `Europe/Berlin`                           |

### Optional alert settings

| Option                     | Description                                                                  |
| -------------------------- | ---------------------------------------------------------------------------- |
| `PA_DISCORD`               | Discord webhook URL for alerts                                               |
| `PA_MASTODON_SERVER`       | Mastodon server URL (e.g. `https://mastodon.social`)                         |
| `PA_MASTODON_ACCESS_TOKEN` | Mastodon access token                                                        |
| `PA_TELEGRAM_BOTTOKEN`     | Telegram bot token                                                           |
| `PA_TELEGRAM_CHATID`       | Telegram chat ID                                                             |
| `PA_EXCLUSIONS`            | Comma-separated list of ICAO hex codes, registrations, or strings to exclude |
| `PF_OPENAIP_LAYER`         | Show OpenAIP overlay on heatmap (`ON` / `OFF`)                               |

## Web UI

The Planefence web interface is available via the **Open Web UI** button in the add-on info page, or via the sidebar panel.

## Notes

- Aircraft are logged to `/data/planefence/` inside the container (persisted across restarts).
- Latitude and longitude are automatically taken from your Home Assistant configuration but can be overridden manually.
- For more details on advanced configuration, see the [upstream documentation](https://github.com/sdr-enthusiasts/docker-planefence).
