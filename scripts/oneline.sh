#!/bin/sh

# Delete repository dir
rm -rf rimap

# Clone repository
git clone https://github.com/iruzo/rimap

# Copy config inside repository
cp config rimap/

# Move inside the repository
cd rimap

# Execute script
sh scripts/build_compose.sh

# Exit repo dir
cd ..

# Move mails outside the repository
mv rimap/mails .

# Delete repository dir
rm -rf rimap
