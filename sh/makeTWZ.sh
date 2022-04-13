#!/bin/bash
set -e
set -x
rm -f T-Wizard.zip
zip -ru T-Wizard.zip T-Wizard.lua SensorFields.jsn T-Wizard
zip -ru DFM.zip T-Wizard.lua SensorFields.jsn T-Wizard
