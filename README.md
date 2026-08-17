# Gemini Character Creator

A lightweight Bash CLI tool that generates multi-angle 16-bit RPG pixel art sprites (Front, Side, and Back views) using the Gemini Image Generation API (`gemini-3-pro-image`).

| Front                                                                                                                                     | Side                                                                                                                                 | Back                                                                                                                                |
| -----------                                                                                                                               | -----------                                                                                                                           | -----------                                                                                                                         |
| ![Front View](https://raw.githubusercontent.com/salivity/gemini-character-creator/refs/heads/main/initial/characters/rpg_1/front.png)     | ![Side View](https://raw.githubusercontent.com/salivity/gemini-character-creator/refs/heads/main/initial/characters/rpg_1/side.png)   | ![Back View](https://raw.githubusercontent.com/salivity/gemini-character-creator/refs/heads/main/initial/characters/rpg_1/back.png) |


To maintain visual consistency across all angles, the script uses a **sequential contextual generation pipeline**:
1. Generates the **Front View** from your text prompt.
2. Feeds the Front View back into the model to generate a matching **Side Profile View**.
3. Feeds both Front and Side views to generate the matching **Back View**.

All sprites are output on a uniform green screen (`#00FF00`) background for easy chroma-keying and sprite sheet integration.

---

## Features

- **Sequential Consistency:** Keeps armor, palette, weapons, and hair identical across Front, Side, and Rear angles using multimodal input chaining.
- **Game-Ready Backgrounds:** Isolated character output on `#00FF00` green screen with crisp pixel edges.
- **Custom Naming & Organization:** Automatically saves rendered PNGs into organized folders under `characters/`.
- **Zero Heavy Frameworks:** Pure Bash script leveraging standard CLI utilities (`curl`, `jq`, `base64`).

---

## Prerequisites

Ensure you have the following CLI tools installed:

- `bash` (v4.0+)
- `curl`
- `jq`
- `coreutils` (`base64`, `tr`, `head`)

### Installing Dependencies

- **Debian / Ubuntu:**
  ```bash
  sudo apt-get update && sudo apt-get install -y curl jq coreutils

## Character Creation

To create a totally random character using defaults try ```bash generate.character.sh```

To change the style of the output image change the prompt with the prompt option EG ```-prompt "Sci-Fi Cyborg"```

The output directory can be changed with the name option EG ```-name "cyborg"```
