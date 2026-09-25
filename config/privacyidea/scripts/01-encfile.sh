#!/bin/bash
# Prevent create_enckey from running since we mount a static encfile
mkdir -p /data/privacyidea/keys
touch /data/privacyidea/keys/encfile
