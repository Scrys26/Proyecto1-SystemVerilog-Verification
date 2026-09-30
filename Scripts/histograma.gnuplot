# ============================================================
# Histograma de retraso total de paquetes
# ============================================================

set datafile separator ","

# ------------------------------------------------------------
# Salida
# ------------------------------------------------------------

set terminal pngcairo enhanced size 1400,800 font "Sans,14"
set output OUT_FILE

# ------------------------------------------------------------
# Estadisticas del CSV
# Columna 8 = retraso total en ciclos
# ------------------------------------------------------------

stats CSV_FILE every ::1 using 8 nooutput

MEDIA   = STATS_mean
MINIMO  = STATS_min
MAXIMO  = STATS_max
TOTAL   = STATS_records

# ------------------------------------------------------------
# Configuracion del histograma
# ------------------------------------------------------------

BIN_WIDTH = 100

bin(x) = BIN_WIDTH * floor(x/BIN_WIDTH) + BIN_WIDTH/2.0

set boxwidth BIN_WIDTH*0.88 absolute
set style fill solid 0.90 border rgb "#174A7E"

# ------------------------------------------------------------
# Titulos
# ------------------------------------------------------------

set title "Histograma del Retraso Total de Paquetes" \
    font "Sans,18"

set xlabel "Retraso total (ciclos de reloj)" \
    font "Sans,14"

set ylabel "Cantidad de paquetes" \
    font "Sans,14"

# ------------------------------------------------------------
# Ejes
# ------------------------------------------------------------

set xrange [0:*]
set yrange [0:*]

set xtics 250
set ytics 5

set tics out
set border 3 back

# ------------------------------------------------------------
# Cuadricula
# ------------------------------------------------------------

set grid ytics back \
    lc rgb "#D9D9D9" \
    dt 2 \
    lw 1

# ------------------------------------------------------------
# Linea de latencia promedio
# ------------------------------------------------------------

set arrow 1 \
    from MEDIA, graph 0 \
    to MEDIA, graph 1 \
    nohead \
    dt 2 \
    lw 2 \
    lc rgb "#D62728"

set label 1 \
    sprintf("Promedio: %.1f ciclos", MEDIA) \
    at MEDIA, graph 0.96 \
    offset 1,0 \
    textcolor rgb "#D62728"

# ------------------------------------------------------------
# Informacion estadistica
# ------------------------------------------------------------

set label 2 \
    sprintf("Paquetes: %d   Min: %.0f   Max: %.0f ciclos", \
            TOTAL, MINIMO, MAXIMO) \
    at graph 0.02, graph 0.95 \
    front

# ------------------------------------------------------------
# Sin leyenda
# ------------------------------------------------------------

unset key

# ------------------------------------------------------------
# Histograma
# ------------------------------------------------------------

plot CSV_FILE every ::1 \
    using (bin(column(8))):(1.0) \
    smooth frequency \
    with boxes \
    lc rgb "#1E88E5"
