set datafile separator ","
set terminal pncario size 1200,700 enhanced font "Arial,12"

set output "Reportes/histograma_latencias.png"

set title "Histograma de Latencia de paquetes "
set xlabel "Latencia (ciclos de reloj)"
set ylabel "Cantidad de paquetes"

set grid ytic
set boxwidth 
set style fill solid 0.7 border -1

set key off 

plot #Reportes/latencias.csv" using 8:(1)\
     smoothh frequency\
     with boxes\
     title "Paquetes"
      