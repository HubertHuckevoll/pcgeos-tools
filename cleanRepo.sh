#!/bin/bash

# go to pcgeos
cd ~/pcgeos

# setzt alle Dateien auf den Stand des aktuellen Zweigs zurück
git reset --hard

# entfernt unversionierte Dateien und Verzeichnisse
git clean -fd
