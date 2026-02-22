# Planefence Add-on

Track aircraft flying near your ADS-B receiver. Planefence logs low-altitude / nearby aircraft, generates noise statistics, and can send alerts via Discord, Mastodon, or Telegram.

This add-on wraps [docker-planefence](https://github.com/sdr-enthusiasts/docker-planefence) by kx1t / SDR-Enthusiasts.

## Before you start

**This add-on requires two things to be set up before it will show any data:**

1. **ADS-B feeder** — The [ADS-B Multi-Portal Feeder](https://github.com/MaxWinterstein/homeassistant-addons) add-on (or any other feeder) must be running and exposing port `30003` (BaseStation/SBS format). Set `PF_SOCK30003HOST` to its hostname.

2. **Location** — Planefence needs to know where your station is. By default it reads `PF_LAT` / `PF_LON` directly from your Home Assistant location. If your HA location is not set, fill them in manually in the add-on options.

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

### Advanced configuration

On first start, the add-on copies the full upstream config template to
`/data/persist/planefence.config`. This file contains all available options
with inline comments — edit it for anything not covered by the UI above (alerts,
filtering, map customisation, etc.). See the [upstream documentation](https://github.com/sdr-enthusiasts/docker-planefence) for details.

The add-on only overwrites the options listed in the table above; everything
else you set manually will survive restarts.

> **Tip:** The [Visual Studio Code add-on](https://github.com/hassio-addons/addon-vscode)
> lets you edit `/addon_configs/planefence/persist/planefence.config` directly
> from your browser.

## Web UI

Once aircraft are being received, the Planefence web interface is available via
the **Open Web UI** button on the add-on info page, or via the sidebar panel.
It may take a few minutes after startup before the first entries appear.
