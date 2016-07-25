U232-V4-Installer
==============

A simple bash script to install U-232-V4, Percona XtraDB, PHP5-FPM, nginx, Adminer, fail2ban and all dependancies.  
This script has been tested on Ubuntu 14.04 LTS.

To use:

```
wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/iv4scr.sh -O iv4scr.sh
chmod a+x iv4scr.sh
nano iv4scr.sh #edit the first few lines
sudo ./iv4scr.sh
```
Or:

```
git clone https://github.com/jonnyboy/U232-V4-Installer.git
cd U232-V4-Installer
nano iv4scr.sh #edit the first few lines
sudo ./iv4scr.sh
```

###TODO  
* add smtp mta
