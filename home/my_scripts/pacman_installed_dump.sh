file="pacman_installed_packages.txt"
# echo "Dump at $(date)" > $file
# echo "------------------------------------" >> $file
pacman -Qqe >> $file
