# Deploy application using temporary application configuration file that
# includes Google OAuth credentials as environment variables

# run: bash deploy_app.sh

# get credentials: GOOGLE_CLIENT_ID & GOOGLE_CLIENT_SECRET
# secret_credentials.sh file is not git tracked because it contains credentials
source secret_credentials.sh

# save file name of temp config file
TEMPFILE="secret.yaml"

# create temp config file (with a name that makes it git ignored!!!)
cat original_app.yaml <(printf "env_variables:\n  GOOGLE_CLIENT_ID: "$GOOGLE_CLIENT_ID"\n  GOOGLE_CLIENT_SECRET: "$GOOGLE_CLIENT_SECRET"\n") > $TEMPFILE

# deploy app, use --no-promote argument to deploy without traffic
gcloud app deploy --no-promote $TEMPFILE
# gcloud app deploy $TEMPFILE

# rm temp config file
rm $TEMPFILE

# test that the file is removed
echo "################################"

if [ -e $TEMPFILE ]; then
    echo "WARNING: file not removed, configuration file with secret credentials still exists."
else
    echo "INFO: remove ok, configuration file does not exist."
fi