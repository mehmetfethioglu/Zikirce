#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Zamera Local Google Play Publisher
Calls the centralized Akarworks Play Publisher with local project defaults.
Zero-Stub, Zero-Mirror, 100% Local-First Release Engine.
"""

import sys
from pathlib import Path

# Add central Akarworks skills script to sys.path
CENTRAL_PUBLISHER = Path("C:/Users/theak/.gemini/config/skills/store-commander/scripts/akarworks_play_publisher.py")

if CENTRAL_PUBLISHER.exists():
    import importlib.util
    spec = importlib.util.spec_from_file_location("akarworks_play_publisher", CENTRAL_PUBLISHER)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["akarworks_play_publisher"] = mod
    spec.loader.exec_module(mod)
    mod.main()
else:
    print(f"Error: Central publisher script not found at {CENTRAL_PUBLISHER}")
    sys.exit(1)
