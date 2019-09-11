# Worktile plugin for Redmine. 
This plugin posts updates to issues in your Redmine installation to Lesschat. 

Forked from [Slack plugin for Redmine](https://github.com/sciyoshi/redmine-slack).


## Installation

From your Redmine plugins directory, clone this repository as `redmine_lesschat` (note
the underscore!):

    git clone https://github.com/worktile/redmine_worktile.git redmine_worktile

You will also need the `restclient` dependency, which can be installed by running

    bundle install

from the plugin directory.

Restart Redmine, and you should see the plugin show up in the Plugins page.
Under the configuration options, set the Lesschat Webhook URL to the URL for an
Incoming WebHook integration in your Lesschat account.

## Customized Routing

You can also route messages to different channels on a per-project basis. To
do this, create a project custom field (Administration > Custom fields > Project)
named `Lesschat Webhook URL`. If no custom channel is defined for a project, the parent
project will be checked (or the default will be used). To prevent all notifications
from being sent for a project, set the custom channel to [Anything other than http...].

For more information, see http://www.redmine.org/projects/redmine/wiki/Plugins.
