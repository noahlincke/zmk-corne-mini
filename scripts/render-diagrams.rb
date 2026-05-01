#!/usr/bin/env ruby

require "tmpdir"
require "yaml"

ROOT = File.expand_path("..", __dir__)
SOURCE_KEYMAP = File.join(ROOT, "config", "corne.keymap")
OUTPUT_YAML = File.join(ROOT, "assets", "corne.keymap.yaml")
OUTPUT_KEYMAP_SVG = File.join(ROOT, "assets", "corne.keymap.svg")
OUTPUT_COMBOS_SVG = File.join(ROOT, "assets", "corne.combos.svg")
OUTPUT_KEYMAP_PNG = File.join(ROOT, "assets", "corne.keymap.png")
OUTPUT_COMBOS_PNG = File.join(ROOT, "assets", "corne.combos.png")
DRAW_ENV = {
  "KEYMAP_KEY_W" => "64",
  "KEYMAP_KEY_H" => "64",
  "KEYMAP_SPLIT_GAP" => "36",
}.freeze

# The source keymap uses the standard 42-position Corne transform, with six
# transparent placeholders for the non-existent outer column on the Mini.
KEEP_GROUPS = [
  [1, 2, 3, 4, 5],
  [6, 7, 8, 9, 10],
  [13, 14, 15, 16, 17],
  [18, 19, 20, 21, 22],
  [25, 26, 27, 28, 29],
  [30, 31, 32, 33, 34],
  [36, 37, 38],
  [39, 40, 41],
].freeze
KEEP_POSITIONS = KEEP_GROUPS.flatten.freeze
POSITION_MAP = KEEP_POSITIONS.each_with_index.to_h.freeze
FIVE_COLUMN_LAYOUT = {
  "zmk_keyboard" => "corne",
  "layout_name" => "five_column_transform",
}.freeze

def run!(*command, env: {})
  return if system(env, *command)

  abort("command failed: #{command.join(' ')}")
end

def executable?(name)
  ENV.fetch("PATH").split(File::PATH_SEPARATOR).any? do |dir|
    path = File.join(dir, name)
    File.executable?(path) && !File.directory?(path)
  end
end

def trim_layers!(data)
  data.fetch("layers").each do |name, rows|
    flat = rows.flatten(1)
    abort("expected 42 positions for #{name}, got #{flat.length}") unless flat.length == 42

    data["layers"][name] = KEEP_GROUPS.map do |group|
      group.map { |index| flat.fetch(index) }
    end
  end
end

def remap_combos!(data)
  data.fetch("combos", []).each do |combo|
    combo["p"] = combo.fetch("p").map { |index| POSITION_MAP.fetch(index) }
  end
end

Dir.mktmpdir("keymap-drawer") do |dir|
  parsed_yaml = File.join(dir, "corne.raw.yaml")

  run!(
    "uvx",
    "--from",
    "keymap-drawer",
    "keymap",
    "parse",
    "-z",
    SOURCE_KEYMAP,
    "-c",
    "5",
    "-o",
    parsed_yaml
  )

  data = YAML.load_file(parsed_yaml)
  trim_layers!(data)
  remap_combos!(data)
  data["layout"] = FIVE_COLUMN_LAYOUT

  File.write(OUTPUT_YAML, YAML.dump(data))

  run!(
    "uvx",
    "--from",
    "keymap-drawer",
    "keymap",
    "draw",
    "--keys-only",
    OUTPUT_YAML,
    "-o",
    OUTPUT_KEYMAP_SVG,
    env: DRAW_ENV
  )
  run!(
    "uvx",
    "--from",
    "keymap-drawer",
    "keymap",
    "draw",
    "--combos-only",
    OUTPUT_YAML,
    "-o",
    OUTPUT_COMBOS_SVG,
    env: DRAW_ENV
  )
end

if executable?("rsvg-convert")
  run!("rsvg-convert", "--width", "1200", "--output", OUTPUT_KEYMAP_PNG, OUTPUT_KEYMAP_SVG)
  run!("rsvg-convert", "--width", "1200", "--output", OUTPUT_COMBOS_PNG, OUTPUT_COMBOS_SVG)
else
  warn("rsvg-convert not found; skipped PNG export")
end
