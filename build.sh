#! /usr/bin/env bash

set -e

cd frontend/
npm run build
cd ..

stack build

killall run-zocalo
