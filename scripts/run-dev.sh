#!/bin/bash
# Quick launch for development environment
flutter run \
  --dart-define=ENV=development \
  --dart-define=API_BASE_URL=http://192.168.100.95:3000 \
  "$@"
