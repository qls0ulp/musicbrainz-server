from fabric.api import *
from time import sleep
from fabric.colors import red
from datetime import date
import re

env.use_ssh_config = True
env.sudo_prefix = "sudo -S -p '%(sudo_prompt)s' -H " % env

def pot():
    """
    Update .pot files
    """
    pot_files = (
        "attributes.pot",
        "instruments.pot",
        "instrument_descriptions.pot",
        "relationships.pot",
        "statistics.pot",
        "languages.pot",
        "languages_notrim.pot",
        "scripts.pot",
        "countries.pot",
    )

    run("mkdir -p /tmp/musicbrainz-pot")
    run("docker exec -u musicbrainz musicbrainz-website-beta bash -c 'cd ~/musicbrainz-server/po && touch extract_pot_db && carton exec -- make %s'" % " ".join(pot_files))
    for pot_file in pot_files:
        run("docker cp musicbrainz-website-beta:/home/musicbrainz/musicbrainz-server/po/%s /tmp/musicbrainz-pot/" % pot_file)

    with lcd("po/"):
        get("/tmp/musicbrainz-pot/*.pot", "./%(path)s")
        run("rm -r /tmp/musicbrainz-pot")
        stats_diff = local("git diff statistics.pot", capture=True)
        local("touch extract_pot_templates")
        local("make mb_server.pot statistics.pot")
        stats_diff = stats_diff + local("git diff statistics.pot", capture=True)

        if not re.match('^\s*$', stats_diff, re.MULTILINE):
            puts("Please ensure that statistics.pot is correct and then commit manually, since it depends on both the database and templates.")
        else:
            local("git add *.pot")
            commit_message = prompt("Commit message", default='Update pot files using current code and production database.')
            local("git commit -m '%s'" % (commit_message))

def deploy(deploy_env="prod"):
    """
    Update the *musicbrainz.org servers.
    """
    services = (
        "musicbrainz-website-" + deploy_env,
        "musicbrainz-webservice-" + deploy_env,
    )
    for svc in services:
        sudo("docker container inspect {0} > /dev/null 2>&1; "
             "if [ $? -eq 0 ]; then "
             "docker stop --time 30 {0} && docker rm {0}; "
             "fi".format(svc))
    sudo("su root -c 'cd /root/docker-server-configs; git pull; ./scripts/start_services.sh; exit 0'")
    local("sleep 15")
