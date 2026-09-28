#!/usr/bin/env python3
"""Inspect a FinderRight release archive without running its executables."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import zipfile

archive = Path(sys.argv[1]).resolve()
expected_executables = {
    "Contents/MacOS/FinderRight",
    "Contents/PlugIns/FinderRightSync.appex/Contents/MacOS/FinderRightSync",
}
macho_magic = {bytes.fromhex(s) for s in ["feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca"]}
with zipfile.ZipFile(archive) as z:
    for entry in z.infolist():
        path = Path(entry.filename)
        assert not path.is_absolute() and ".." not in path.parts, "Unsafe ZIP path"
        assert path.parts[0] == "FinderRight.app", "Unexpected ZIP root"
        assert not stat.S_ISLNK(entry.external_attr >> 16), "Unexpected bundled symlink"
    with tempfile.TemporaryDirectory(prefix="FinderRight-audit-") as folder:
        subprocess.run(["/usr/bin/ditto", "-x", "-k", str(archive), folder], check=True)
        app = Path(folder) / "FinderRight.app"
        actual = set()
        for path in app.rglob("*"):
            if path.is_file():
                with path.open("rb") as f:
                    if f.read(4) in macho_magic:
                        actual.add(str(path.relative_to(app)))
        assert actual == expected_executables, f"Unexpected executable inventory: {actual}"
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        assert (app / "Contents/Resources/LICENSE").read_bytes() == (Path(__file__).resolve().parent.parent / "LICENSE").read_bytes()
        for executable in sorted(actual):
            path = app / executable
            subprocess.run(["/usr/bin/lipo", str(path), "-verify_arch", "arm64", "x86_64"], check=True)
            listing = subprocess.check_output(["/usr/bin/otool", "-L", str(path)], text=True)
            dependencies = [line.strip().split(" (", 1)[0] for line in listing.splitlines() if line.startswith("\t")]
            assert all(p.startswith(("/System/Library/", "/usr/lib/")) for p in dependencies), "Non-system library found"
        entitlement_summary = {}
        for bundle in [app, app / "Contents/PlugIns/FinderRightSync.appex"]:
            signature = subprocess.run(["/usr/bin/codesign", "-dvv", str(bundle)], capture_output=True, text=True, check=True).stderr
            assert "runtime" in signature, "Hardened Runtime missing"
            result = subprocess.run(["/usr/bin/codesign", "-d", "--entitlements", ":-", str(bundle)], capture_output=True, check=True)
            entitlements = plistlib.loads(result.stdout) if result.stdout.strip() else {}
            assert not entitlements.get("com.apple.security.get-task-allow"), "Debug entitlement found"
            assert not any(k.startswith("com.apple.security.network") for k in entitlements), "Unexpected network entitlement"
            assert "com.apple.security.temporary-exception.sbpl" not in entitlements
            assert "com.apple.security.temporary-exception.apple-events" not in entitlements
            entitlement_summary[bundle.name] = sorted(entitlements)
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        extension_info = plistlib.loads((app / "Contents/PlugIns/FinderRightSync.appex/Contents/Info.plist").read_bytes())
        assert info["CFBundleVersion"] == extension_info["CFBundleVersion"]
        assert info["CFBundleShortVersionString"] == extension_info["CFBundleShortVersionString"]
        report = {
            "archive": archive.name,
            "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"],
            "executables": sorted(actual),
            "dependencies": "Apple frameworks and system libraries only",
            "entitlements": entitlement_summary,
            "signature_verification": "passed",
            "hardened_runtime": True,
            "notarized": False,
            "license_included": True,
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))
