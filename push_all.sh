for dir in botapp botserver botlib botui botbook bottest botdevice botmodels botplugin bottemplates .github; do
  echo "--- Processing $dir ---"
  cd $dir
  git add -u
  git commit -m "update: sync for alm" || true
  ORIGIN_URL=$(git config --get remote.origin.url)
  REPO_NAME=$(basename $ORIGIN_URL)
  git remote remove alm 2>/dev/null || true
  git remote add alm "https://alm.pragmatismo.com.br/GeneralBots/$REPO_NAME"
  git push alm HEAD:main || git push alm HEAD:master || echo "Failed to push $dir"
  cd ..
done
