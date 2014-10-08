#!/usr/bin/env perl
use strict;
use warnings;

use WebService::Zulip;
use Data::Printer;

# take options
# daemonize
# fork off two workers -- one for processing input, one for output

__END__

=head1 zulip-irc-ii

zulip-irc-ii - Transport messages between Zulip and IRC using ii

=head1 USAGE

	./zulip-irc-ii -d /path/to/ii/channel/dir -f /path/to/zulip/creds

=head1 DESCRIPTION

zulip-irc-ii allows you to interact with Zulip over IRC. Specifically,
zulip-irc-ii works in concert with ii, a FIFO-based IRC client. Install ii,
and have it join the IRC network and channel of your choice. Then, run
zulip-irc-ii (ZI3). ZI3 puts new messages into the IRC channel, and monitors your
responses to send messages back to Zulip.

=head1 DEPENDENCIES

zulip-irc-ii depends on ii, a FIFO-based IRC client.

zulip-irc-ii is written in perl, and depends on the not-yet-uploaded
WebService::Zulip module.

=head1 EXAMPLES

Install ii, then join it to an IRC network of your choice. For example,

    ii -s irc.freenode.org -p 6667 -n zulipbot -f zulipbot -i /tmp/ii

You'll want to read the ii man page for descriptions of the commands. Then, you
can join your bot to a channel with a command like

    echo '/j ##zulip-for-me' > /tmp/ii/irc.freenode.org/in

Once it's joined, run zulip-irc-ii:

    ./zulip-irc-ii -d /tmp/ii/irc.freenode.org/\#\#zulip-for-me -f .zulip-rc

You should see new messages in the channel. You can respond to messages by
<doing some thing I haven't figured out yet, etc etc regex>

=head1 BUGS

The code doesn't exist yet

=head1 AUTHOR

Stan Schwertly (http://www.schwertly.com)