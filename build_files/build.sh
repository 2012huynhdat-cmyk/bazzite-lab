#!/bin/bash

set -euo pipefail

# Stage 1 intentionally leaves the Bazzite NVIDIA Open base unchanged.
# Future image customizations belong here; do not install template examples
# or copy the empty system_files placeholders into the image.
