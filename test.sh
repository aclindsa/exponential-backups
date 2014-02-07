rm -f test_latest test_results
touch test_results

for (( ago=100; ago>=0; ago-- )); do
  backup_date=$( date -I -d "$ago days ago")
  echo $backup_date >> test_latest
  grep -v "_" test_latest | ./binary_backups.sh -r -d "$backup_date" | xargs -I "{}" sed -ri "s/{}/__________/g" test_latest
  mv test_results test_results_old
  paste -d " " test_latest test_results_old > test_results
done

rm test_results_old
