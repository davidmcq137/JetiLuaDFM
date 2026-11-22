#!/bin/bash
set -e
set -x
rm -f zip/T-Wizard.zip
zip -ru zip/T-Wizard.zip T-Wizard.lua SensorFields.jsn T-Wizard
zip -ru zip/DFM.zip T-Wizard.lua SensorFields.jsn T-Wizard
