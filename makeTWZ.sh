#!/bin/bash
set -e
set -x
rm -f T-Wizard.zip
zip -ru T-Wizard.zip T-Wizard.lua SensorE.lua SensorE.jsn SensorFields.jsn T-Wizard
