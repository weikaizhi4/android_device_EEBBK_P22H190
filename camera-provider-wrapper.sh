#!/vendor/bin/sh

# The Android 11 provider exits on EPIPE when SIGPIPE is left at its default.
# Ignore it before replacing the wrapper with the vendor service.
trap '' PIPE
exec /vendor/bin/hw/android.hardware.camera.provider@2.4-service "$@"
