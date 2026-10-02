# HomeDicator

An LVGL dashboard for the Seeed SenseCAP Indicator that shows and controls Home Assistant entities. It's an ESPHome package: you write one small config file in Home Assistant that lists your pages and tiles, and ESPHome fetches everything else from this repository.

Based on [HomeDicator](https://github.com/HomeDicator) by Paul-Vincent Roll. GPL-3.0.

## Use it in Home Assistant

1. Copy [`examples/sensecap.yaml`](examples/sensecap.yaml) into the ESPHome folder of Home Assistant (`/config/esphome/<name>.yaml`).
2. Add `api_key`, `ota_key`, `wifi_ssid` and `wifi_password` to `/config/esphome/secrets.yaml`. Secrets never go into this repository.
3. Change the `files:` list to the pages and tiles you want, then click **Install**.

To update, change `ref:` to a newer release tag and install again.

### Building blocks

Every entry in `files:` is one block. Pages appear in the order listed, after the settings page. A tile goes onto the page named by its `page_id`, in the order listed. `entity` is the Home Assistant entity id without its domain (`kitchen`, not `climate.kitchen`).

| File | What it adds | vars |
|---|---|---|
| `device/seeed-sensecap-indicator.yaml` | Hardware, settings and about pages, clock, pager | – |
| `pages/grid.yaml` | A page with a title and a tile grid | `page_id`, `title` |
| `tiles/sensor_square.yaml` | Sensor value | `page_id`, `entity`, `title`, `icon`, `unit`, `color` |
| `tiles/sensor_wide.yaml` | Sensor value, double width | `page_id`, `entity`, `title`, `icon`, `unit`, `color` |
| `tiles/thermostat_square.yaml` | Target temperature dial | `page_id`, `entity`, `title`, `color`, `min_value`, `max_value` |
| `tiles/thermostat_wide.yaml` | Target temperature slider | `page_id`, `entity`, `title`, `unit`, `min_value`, `max_value` |
| `tiles/thermostat_wide_half_height.yaml` | Compact slider, icon left | `page_id`, `entity`, `icon`, `unit`, `color`, `min_value`, `max_value` |
| `tiles/thermostat_wide_half_height_icon_right.yaml` | Compact slider, icon right | `page_id`, `entity`, `icon`, `unit`, `color`, `min_value`, `max_value` |

- `icon` is a [Material Design Icons](https://pictogrammers.com/library/mdi/) codepoint such as `"\U000F0F55"`. It must be in the glyph list in `core/config/common/fonts.yaml`.
- `color` is a hex number such as `0xeebf41`.
- The same entity can be on several pages, but only once per page.

Optional substitutions:

| Substitution | Default | Meaning |
|---|---|---|
| `screen_off_after` | `"Never"` | Default "Turn off screen after" setting: `"Never"`, `"1 min"`, `"5 min"` or `"15 min"` (anything else fails the build). A device stores the setting on its first boot with this version and keeps it from then on, so later changes to this substitution only reach new devices; change it on the screen instead. |
| `page_transition_time` | `150ms` | Page swipe animation length |
| `user_interface_debug_mode` | `"false"` | `"true"` draws layout borders |
| `homedicator_release_repo` | `herpaderpaldent/HomeDicator` | Repo the settings page checks for updates |

You can add your own ESPHome config below the package in the same file. Your own `lvgl: pages:` are appended after the package pages, and `!extend` / `!remove` work on package ids such as `<page_id>_grid`.

### Versioning

File paths and vars are the public interface. Renaming or removing one is a new major version, so a pinned `ref:` keeps working until you choose to update.

## Development

Run the UI in a window on your computer:

1. [Install ESPHome](https://esphome.io/guides/installing_esphome.html) and the [SDL requirements](https://esphome.io/components/display/sdl.html).
2. `esphome run examples/sdl.yaml`

`examples/sdl.yaml` uses local `!include`s with the same files and vars as a real config, so changes show up without pushing.

`scripts/render.sh --docker` renders every page of the example (with fake sensor values) to `renders/*.png` by tapping through the real navigation. CI runs the same script on every push and pull request, uploads the images as the **renders** artifact, and also validates both examples on the oldest supported ESPHome and the version Home Assistant ships.

To release: bump `homedicator_core_version_tag` in `core.yaml`, then tag the commit with the same value and push the tag.
