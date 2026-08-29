#!/bin/sh

echo "If you are reading this, this is an image produced by a skeleton/template."

if [ -f /app/template.txt ]; then
    cat /app/template.txt
else
    echo "No template file found"
fi

echo "Environment: $ENV"
