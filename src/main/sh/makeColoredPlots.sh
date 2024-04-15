#!/bin/bash
#
tomorrow=$(date -I -d tomorrow)
#
cp /mnt/SSD_disk1/tomorrow_Trondheim.png /mnt/SSD_disk1/today_Trondheim.png
grep "${tomorrow}" /mnt/SSD_disk1/electric.json | grep Trondheim | tail -1 > TRD-"${tomorrow}".json
./generatePlotData.sh TRD-"${tomorrow}".json > TRD-"${tomorrow}".plt
gnuplot -c ../plot/plotPrices.gp TRD-"${tomorrow}".plt "${tomorrow}" EUR MWh TRD.png
cp TRD.png /mnt/SSD_disk1/tomorrow_Trondheim.png
#
cp /mnt/SSD_disk1/tomorrow_Finland.png /mnt/SSD_disk1/today_Finland.png
grep "${tomorrow}" /mnt/SSD_disk1/electric.json | grep Finland | tail -1 > FIN-"${tomorrow}".json
./generatePlotData.sh FIN-"${tomorrow}".json > FIN-"${tomorrow}".plt
gnuplot -c ../plot/plotPrices.gp FIN-"${tomorrow}".plt "${tomorrow}" EUR MWh FIN.png
cp FIN.png /mnt/SSD_disk1/tomorrow_Finland.png
