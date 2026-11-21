import re
import sys
from pathlib import Path

A2DP_PORT = '        <mixPort name="a2dp output" role="source"/>'
A2DP_PORT_PROFILE = '''        <mixPort name="a2dp output" role="source">
            <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                     samplingRates="44100"
                     channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
        </mixPort>'''


def replace_once(text, old, new, description):
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"cannot apply {description}")
    return text.replace(old, new, 1)


def insert_after(text, anchor, addition, description):
    if addition in text:
        return text
    if anchor not in text:
        raise SystemExit(f"cannot apply {description}")
    return text.replace(anchor, anchor + addition, 1)


def patch_a2dp_port(text):
    return replace_once(text, A2DP_PORT, A2DP_PORT_PROFILE, "a2dp mixPort profile")


def patch_composer_rc(text):
    text = replace_once(
        text,
        "/vendor/bin/hw/android.hardware.graphics.composer@2.1-service",
        "/vendor/bin/hw/eebbk.graphics.composer-service",
        "composer service path",
    )
    return replace_once(
        text,
        "    writepid /dev/cpuset/system-background/tasks\n",
        "    task_profiles ServiceCapacityLow\n",
        "composer task profile",
    )


def patch_init_md_rc(text):
    text = replace_once(
        text,
        "\non post-fs-data\n    mkdir /data/vendor/local/otpdata 0777 system root\n",
        "\non post-fs-data\n    restorecon_recursive /mnt/vendor\n"
        "    mkdir /data/vendor/local/otpdata 0777 system root\n",
        "vendor label restore",
    )
    for block in (
        "# device/sprd/mpool/module/wcn/mfeature/kernel/kernel4.14/kernel4.14.rc\n"
        "on property:persist.vendor.eng.sprdwl=1\n"
        "\tinsmod /vendor/lib/modules/sprdwl_ng.ko\n",
        "# device/sprd/mpool/module/wcn/mfeature/kernel/kernel4.14/kernel4.14.rc\n"
        "on property:persist.vendor.eng.sprdwl=1\n"
        "\tinsmod /vendor_dlkm/lib/modules/sprdwl_ng.ko\n",
    ):
        if block in text:
            return text.replace(block, "", 1)
    return text


def patch_enhance_rc(text):
    anchor = "service vendor.enhance-hal-1-0 /vendor/bin/hw/vendor.sprd.hardware.enhance@1.0-service\n"
    return insert_after(
        text,
        anchor,
        "    interface vendor.sprd.hardware.enhance@1.0::IEnhance default\n",
        "enhance interface declaration",
    )


H264_BLOCK = re.compile(
    r'[ \t]*<MediaCodec name="OMX\.sprd\.h264\.encoder" type="video/avc">.*?</MediaCodec>\n',
    re.DOTALL,
)


def patch_media_codecs(text):
    match = H264_BLOCK.search(text)
    if not match:
        return text
    block = match.group(0)
    if text.find(block, 0, text.find("OMX.sprd.mpeg4.encoder")) >= 0:
        return text
    block = block.replace('range="1-245760"', 'range="12-245760"')
    body = text[:match.start()] + text[match.end():]
    anchor = "<Encoders>\n"
    if anchor not in body:
        raise SystemExit("cannot apply h264 encoder ordering")
    return body.replace(anchor, anchor + block, 1)


def patch_usb_audio_policy(text):
    if "Horizon_add" not in text:
        return text
    text = re.sub(r"[ \t]*<!--[ \t]*Horizon_add[ \t]*\n", "", text)
    return re.sub(r"[ \t]*-->[ \t]*\n(?=[ \t]*(</devicePorts>|</routes>))", "", text)


def patch_keymaster_manifest(text):
    return replace_once(
        text,
        "        <name>IKeymasterDevice</name>\n",
        "            <name>IKeymasterDevice</name>\n",
        "keymaster interface indent",
    )


HANDLERS = {
    "bluetooth_audio_policy_configuration_disable_offload.xml": patch_a2dp_port,
    "eebbk.graphics.composer-service.rc": patch_composer_rc,
    "init.md.rc": patch_init_md_rc,
    "vendor.sprd.hardware.enhance@1.0-service.rc": patch_enhance_rc,
    "media_codecs.xml": patch_media_codecs,
    "usb_audio_policy_configuration.xml": patch_usb_audio_policy,
    "android.hardware.keymaster@4.1-unisoc.service.xml": patch_keymaster_manifest,
}


def main():
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} FILE", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    handler = HANDLERS.get(path.name)
    if handler is None:
        print(f"no rule for {path.name}", file=sys.stderr)
        return 1
    original = path.read_text(encoding="utf-8")
    patched = handler(original)
    if patched != original:
        path.write_text(patched, encoding="utf-8")
        print(f"patched {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
