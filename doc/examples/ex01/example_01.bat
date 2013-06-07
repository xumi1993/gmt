REM
REM		GMT EXAMPLE 01
REM
REM		$Id$
REM
REM Purpose:	Make two contour maps based on the data in the file osu91a1f_16.nc
REM GMT progs:	gmtset, grdcontour, psbasemap, pscoast
REM DOS calls:	del
REM
echo GMT EXAMPLE 01
set ps=example_01.ps
gmt gmtset MAP_GRID_CROSS_SIZE_PRIMARY 0 FONT_ANNOT_PRIMARY 10p
gmt psbasemap -R0/6.5/0/9 -Jx1i -B0 -P -K > %ps%
gmt pscoast -Rg -JH0/6i -X0.25i -Y0.5i -O -K -Bg30 -Dc -Glightbrown -Slightblue >> %ps%
gmt grdcontour osu91a1f_16.nc -J -C10 -A50+f7p -Gd4i -L-1000/-1 -Wcthinnest,- -Wathin,- -O -K -T0.1i/0.02i >> %ps%
gmt grdcontour osu91a1f_16.nc -J -C10 -A50+f7p -Gd4i -L-1/1000 -O -K -T0.1i/0.02i >> %ps%
gmt pscoast -Rg -JH6i -Y4i -O -K -B+t"Low Order Geoid" -Bg30 -Dc -Glightbrown -Slightblue >> %ps%
gmt grdcontour osu91a1f_16.nc -J -C10 -A50+f7p -Gd4i -L-1000/-1 -Wcthinnest,- -Wathin,- -O -K -T0.1i/0.02i:-+ >> %ps%
gmt grdcontour osu91a1f_16.nc -J -C10 -A50+f7p -Gd4i -L-1/1000 -O -T0.1i/0.02i:-+ >> %ps%
del .gmt*
del gmt.conf
