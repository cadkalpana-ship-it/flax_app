#!/bin/bash

# 1. Clone the stable Flutter SDK repository from GitHub
git clone https://github.com -b stable --depth 1

# 2. Add the newly downloaded Flutter binary path to the active environment
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Disable telemetry reporting to speed up the installation process
flutter config --no-analytics

# 4. Compile the application into a highly compressed production web bundle
flutter build web --release
