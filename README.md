# zulip-irc-ii

zulip-irc-ii - Transport messages between Zulip and IRC using ii. This
software includes the raw script that allows you to transport messages,
and an init script that allows your to configure zulip-irc-ii to your needs.

# USAGE

    # Fill out zulip-to-irc.conf with IRC settings 
    # and .zulip-rc with Zulip credentials 
    ./zulip-to-irc start

# DESCRIPTION

zulip-irc-ii allows you to interact with Zulip over IRC. Specifically,
zulip-irc-ii works in concert with ii, a FIFO-based IRC client. Install ii,
and have it join the IRC network and channel of your choice. Then, run
zulip-irc-ii.pl (ZI3). ZI3 puts new messages into the IRC channel, and monitors your
responses to send messages back to Zulip.

You have the option of running zulip-irc-ii.pl directly and managing ii yourself,
or using the provided init script with a populated config file for running.

The .zulip-rc file is JSON, a hash of "api_key" and "api_user". The zulip-to-irc
config file is bash and follows the VAR=VALUE syntax. The "translations" file is
also a JSON file of key->value.

# DEPENDENCIES

zulip-irc-ii depends on ii, a FIFO-based IRC client.

zulip-irc-ii is written in perl, and depends on the not-yet-uploaded
WebService::Zulip module. Until it's uploaded, you can clone WebService::Zulip,
and put the following line in your zulip-to-irc.conf:

    PERL5LIB=/path/to/WebService-Zulip/lib

zulip-irc-ii uses the JSON, File::Tail, and Net::Server::Daemonize CPAN
modules.

# EXAMPLES

Fill out the zulip-to-irc.conf file, and run

    ./zulip-to-irc start

You can start, stop, restart, and check the status of zulip-to-irc. Using the software
is easy. Join the channel you configured in zulip-to-irc.conf and you'll see new messages
flowing in. zulip-to-irc watches for messages from you. For example, in order to send a message to
a stream named 'Victory' with a topic of 'IRC'

    Victory/IRC: wow, I can't believe this works!

You can use the short names presented by zulip-to-irc to respond to mentions:

	Victory/IRC: @maxim thanks!

You can send and respond to private messages with the email address of the user. This
is mostly a deficiency in the current program. It should take a short name.

    stan@schwertly.com: this feature is less useful

Zulip-to-irc allows you define translations in JSON. For example, a heart emoji in
Zulip is shown with ':heart:'. You can specify a JSON translation file to automatically
translate messages with '<3' into ':heart:'.

# BUGS

There are plenty of things this doesn't do. Those are technically bugs, but they aren't great.
Tell me if you find any.

# AUTHOR

Stan Schwertly (http://www.schwertly.com)
