cp /mnt/SSD_disk1/tomorrow_Trondheim.png /mnt/SSD_disk1/today_Trondheim.png
grep $(date -I -d tomorrow) /mnt/SSD_disk1/electric.json | grep Trondheim | tail -1 > TRD-$(date -I -d tomorrow).json
./generatePlotData.sh TRD-$(date -I -d tomorrow).json > TRD-$(date -I -d tomorrow).plt
gnuplot -c ../plot/plotPrices.gp TRD-$(date -I -d tomorrow).plt $(date -I -d tomorrow) EUR MWh TRD.png
cp TRD.png /mnt/SSD_disk1/tomorrow_Trondheim.png

cp /mnt/SSD_disk1/tomorrow_Finland.png /mnt/SSD_disk1/today_Finland.png
grep $(date -I -d tomorrow) /mnt/SSD_disk1/electric.json | grep Finland | tail -1 > FIN-$(date -I -d tomorrow).json
./generatePlotData.sh FIN-$(date -I -d tomorrow).json > FIN-$(date -I -d tomorrow).plt
gnuplot -c ../plot/plotPrices.gp FIN-$(date -I -d tomorrow).plt $(date -I -d tomorrow) EUR MWh FIN.png
cp FIN.png /mnt/SSD_disk1/tomorrow_Finland.png

