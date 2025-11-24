#!/bin/bash

echo "Ì¥• Destroying old environment..."
vagrant destroy -f

echo "Ì∫Ä Starting automated deployment..."
vagrant up

echo "‚úÖ Deployment Finished!"
echo "Ìºç Access the App here: https://192.168.56.11"
