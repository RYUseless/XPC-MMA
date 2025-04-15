#!/bin/bash

if ! source .venv/bin/activate; then
  echo "Failed to activate virtual environment"
  exit 2
fi