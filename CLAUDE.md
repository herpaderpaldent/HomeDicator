# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

HomeDicator is an LVGL-based Home Assistant dashboard firmware for a 480x480 touch display (Seeed SenseCAP Indicator), published as a public ESPHome **remote package**. Users don't copy this repo. They write one config in Home Assistant whose `packages: homedicator: {url, ref, files: [...]}` lists a device file plus page and tile files with `vars` (see `examples/sensecap.yaml` and the README table). Everything is ESPHome YAML with inline C++ lambdas. There is no build system or test suite beyond ESPHome itself.

## Commands

Requires ESPHome plus the SDL2 requirements for the `sdl` display platform.

- Run the UI on the desktop: `esphome run examples/sdl.yaml`
- Validate / compile: `esphome config examples/sdl.yaml`, `esphome compile examples/sdl.yaml`

- Render all pages to PNG: `scripts/render.sh --docker` (Linux without `--docker` needs Xvfb, xdotool, ImageMagick, SDL2). It uses `examples/render.yaml`, which feeds fake values via `publish_state` on the `${page_id}__${entity}` sensor ids, so update it when the example tiles change. The script fails if a tap on the right edge doesn't change the page.
- CI (`.github/workflows/ci.yml`) validates on the oldest supported version and the HA add-on version, then renders. On pushes to `main` it force-pushes the PNGs as a single-commit orphan branch `renders`, which the README embeds via raw.githubusercontent.com. Never commit renders to `main`. `examples/render.yaml` pins the clock to 12:00 so the images only change when the UI does.

`examples/sdl.yaml` uses local `!include`s with the same files and vars a remote config uses, and it exercises every tile type. Check changes against both the local ESPHome and the version the HA add-on ships, because the add-on uses LVGL 9 from 2026.x. To test the real remote path, point a scratch copy of `examples/sensecap.yaml` at `url: file:///<this repo>` with `ref: <branch>` and `refresh: 0s`. A `file://` package only sees **committed** content. Remote packages switch off ESPHome's secret masking, so `esphome config` output contains secret values.

## Architecture

**Public interface.** The file paths under `device/`, `pages/` and `tiles/`, and their vars, are the API users pin with `ref:`. Renaming or removing either is a breaking change and needs a new major version.

**Layering**
- `device/<device>.yaml` → nested `packages: HomeDicatorBase: !include ../core.yaml` → `core.yaml`, which assembles common config via `<<: !include core/config/common/*.yaml`, plus `core/config/device/<device>/hardware.yaml`.
- `device/sdl.yaml` uses `!remove` for pieces that don't work on the `host` platform.
- All `!include` paths are relative to the including file, which makes them work inside the remote clone. **Never add anything that resolves against the user's config dir**, such as `esphome: includes:` or local `file:` paths. That's why `adjust_color` is inlined in `user_interface/templates/tiles/thermostat/square.yaml`.

**Pages and tiles**
- `pages/grid.yaml` defines LVGL page `${page_id}` containing obj `${page_id}_grid`.
- Each `tiles/*.yaml` is a top-level package that pairs two templates:
  - an HA data template from `core/templates/` (`sensor:` list item)
  - a widget template from `user_interface/templates/tiles/`, inserted via `lvgl: pages: - id: !extend ${page_id} → obj id: !extend ${page_id}_grid → widgets`
- Package vars act as substitutions for the nested `!include`s. A nested `!include` with its own `vars` (e.g. the cover helpers in `user_interface/templates/tiles/cover/helpers/`) still sees the outer ones such as `${page_id}` and `${entity}`.
- All per-tile ids are `${page_id}__${entity}`: the sensor id, `lvgl_value_label_…`, `lvgl_arc_…` / `lvgl_slider_…`. When one entity needs several of them, a suffix is appended (cover tilt: `${page_id}__${entity}__tilt`). The same entity can appear on several pages, but only once per page. Data and widget templates must agree on these ids.

**Merge order.** ESPHome concatenates lists with the deepest package first: core's `settings` and `about` (skip) pages, then the user's `files:` entries in the order listed, then the user's own YAML. `!extend` / `!remove` resolve after merging.

**Pager**
- There is no page count to configure. At boot (`esphome.yaml` on_boot 250), `init_pager` in `core/config/common/scripts.yaml` walks all pages via the public `LvglComponent::show_next_page` / `get_current_page`, fills the `page_order` and `pager_dots` vectors (`globals.yaml`), then lands on the first user page.
- `next_page` / `previous_page` call `update_pager_dots`.
- Don't reach into `LvglComponent` internals: `pages_` is protected and the class is `final` in 2026.x.

**Slider interaction.** The `user_is_interacting` global is set while an arc or slider is being dragged, and incoming HA updates are ignored during that time. Arcs and sliders start disabled and are enabled on the first value. `tiles/thermostat/helpers/on_value.yaml` sends `climate.set_temperature` on every change while dragging. Cover sliders (`tiles/cover/helpers/slider.yaml`) send `cover.set_cover_position` / `set_cover_tilt_position` once on release and then follow the intermediate positions HA reports.

**Versioning and settings**
- `homedicator_core_version_tag` in `core.yaml` is the release version. The settings/about page compares it with the latest GitHub release of `${homedicator_release_repo}` (`core/config/common/interval.yaml`).
- To release: bump the tag value, commit, `git tag` the same value, push the tags.
- `core.yaml` substitutions are defaults the user can override: `page_transition_time`, `user_interface_debug_mode`, `homedicator_release_repo`.
- The user must provide `device_name`, `device_friendly_name` and `api_key`. On real hardware they must also provide `ota_key`, `wifi_ssid` and `wifi_password`, via `!secret` in their own HA file.

**UI odds and ends**
- The `top_layer` (`user_interface/pages/top_layer/`) holds the clock, wifi, pager dots and invisible navigation tap areas.
- Styles live in `user_interface/theme/style_definitions.yaml`.
- Icons are Material Design Icons codepoints and must be in the glyph lists in `core/config/common/fonts.yaml`.
- Idle and burn-in: `lvgl.on_idle` plus the `activity_timeout_reached` / `activity_detected` scripts.
