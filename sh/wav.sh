set -e
set -x
ls DFM-Maps/Lang/en/Audio > en.out
ls DFM-Maps/Lang/fr/Audio > fr.out
ls DFM-Maps/Lang/de/Audio > de.out
ls DFM-Maps/Lang/cz/Audio > cz.out
cat en.out fr.out de.out cz.out > all.out
sort all.out > alls.out
uniq alls.out -c > alls.uout
