package Workhorse::Functions::WorkhorseManagement;

use strict;
no strict 'refs';
use Carp;
use JSON::XS;
use YAML::Syck;
use Workhorse::Config;
our $VERSION = "0.01";
our $AUTOLOAD;

=head1 NAME

Workhorse::Functions::WorkhorseManagement

=head2 DESCRIPTION

Provides daemon management for the Workhorse daemon

=head1 PUBLIC METHODS

=cut

=head2 new

  Constructor

=cut

our $NAME        = 'workhorse_management';
our $DESCRIPTION = 'Provides daemon management for the Workhorse daemon';

my %fields = (
    name      => $NAME,
    groupchat => undef,
    chat      => undef,
);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = { _permitted => \%fields, %fields };
    bless( $self, $class );
    $self->{chat}      = \&_return_workhorse_management;
    $self->{groupchat} = \&_return_workhorse_management_group;
    return $self;
}

=head1 PRIVATE METHODS

=cut

=head2 _send_reply( $message, $rtext, $jsontext )
  
  Generate reply to message

=cut

sub _send_reply {
    my ( $message, $rtext, $jsontext ) = @_;
    if ( $rtext and $jsontext ) {
        chomp($rtext);
        my $reply = $message->make_reply;
        $reply->add_body( $rtext, 'en', $jsontext, 'json' );
        $reply->send;
        return 1;
    }
    elsif ($rtext) {
        chomp($rtext);
        my $reply = $message->make_reply;
        $reply->add_body( $rtext, 'en' );
        $reply->send;
        return 1;
    }

    return 0;
}

=head2 _return_workhorse_management

  Direct message handler

=cut

sub _return_workhorse_management {
    my ( $connection, $message ) = @_;
    return 0 unless ( $connection && $message );
    my $rtext;
    my $jsontext;

    my $config   = Workhorse::Config::object;
    my $fromuser = Workhorse->get_user( $message->from );

    my $help =
        "\nUsage:\n\tworkhorse <command> <optional>\n\n"
      . "Information Commands:\n\thelp - Displays this help guide\n"
      . "\tversion - Displays version information on program and installed handlers\n"
      . "\t\t(optional <Module> - Limits display to just listed module)\n"
      . "\thandlers - Provides a list of installed handlers\n"
      . "\t\t(optional <all|active|inactive|unknown) - Limits handlers listed to specific type)\n"
      . "\tusers - Provides a list of recognized users\n"
      . "\thandles - Provides a list of recognized MUC Handles/Aliases/Nicknames\n";

    my $users = $config->('users');
    my $su = ( $users->{$fromuser}->{allowed} eq 'all' ) ? 1 : 0;

    if ($su) {
        $help .=
            "\nAdministration Commands:\n"
          . "\tadd - Add something\n"
          . "\t\tuser - Adds a user with no access\n"
          . "\t\t\t(required <user> - username\@domain to add)\n"
          . "\t\thandle - Adds a handle with link to valid user\n"
          . "\t\t\t(required <link> - username\@domain to link to, <handle> - Handle/Alias linked to user)\n"
          . "\t\taccess - Grants user access to a handler\n"
          . "\t\t\t(required <user> - username\@domain to be granted access, <handler> - Name of handler to grant access to)\n"
          . "\tremove - Remove something\n"
          . "\t\tuser - Removes a non superuser\n"
          . "\t\t\t(required <user> - username\@domain to remove)\n"
          . "\t\thandle - Removes a handle\n"
          . "\t\t\t(required <handle> - Handle/Alias to remove)\n"
          . "\t\taccess - Denies user access to a handler\n"
          . "\t\t\t(required <user> - username\@domain to be denied access, <handler> - Name of handler to deny access to)\n";
    }

    if ( $message->body('json') ) {
        my $coder   = JSON::XS->new->utf8->pretty->allow_nonref;
        my $request = $coder->decode( $message->body('json') );

        if ( $request->{handler} =~ m/^workhorse$/i ) {
            if ( $request->{command} =~ m/^handlers$/i ) {
                ( $rtext, $jsontext ) = _list_handlers( $message, $request );
            }
            elsif ( $request->{command} =~ m/^users$/i ) {
                ( $rtext, $jsontext ) = _list_users($request);
            }
            elsif ( $request->{command} =~ m/^handles$/i ) {
                ( $rtext, $jsontext ) = _list_handles($request);
            }
            elsif ( $su and $request->{command} =~ m/^add$/i ) {
                ( $rtext, $jsontext ) =
                  _admin_add_handler( $message, $request );
            }
            elsif ( $su and $request->{command} =~ m/^remove$/i ) {
                ( $rtext, $jsontext ) =
                  _admin_remove_handler( $message, $request );
            }
        }
        else { return 0; }
    }
    elsif ( $message->any_body =~ m/^workhorse\s+(\w+)/i ) {
        my $command = lc($1);
        if ( $command eq 'help' ) {
            $rtext = $help;
        }
        elsif ( $command =~ m/^handlers$/i ) {
            ( $rtext, $jsontext ) = _list_handlers($message);
        }
        elsif ( $command =~ m/^version$/i ) {
            ( $rtext, $jsontext ) = _list_versions($message);
        }
        elsif ( $command =~ m/^users$/i ) {
            ( $rtext, $jsontext ) = _list_users();
        }
        elsif ( $command =~ m/^handles$/i ) {
            ( $rtext, $jsontext ) = _list_handles();
        }
        elsif ( $su and $command =~ m/^add$/i ) {
            ( $rtext, $jsontext ) = _admin_add_handler($message);
        }
        elsif ( $su and $command =~ m/^remove$/i ) {
            ( $rtext, $jsontext ) = _admin_remove_handler($message);
        }
        else {
            $rtext = 'Unknown command: ' . $command . $help;
        }
    }
    elsif ( $message->any_body =~ m/^workhorse/i ) { $rtext = $help }
    else                                           { return 0 }

    return _send_reply( $message, $rtext, $jsontext );
}

=head2 _return_workhorse_management_group

  Group message handler

=cut

sub _return_workhorse_management_group {
    my ( $connection, $message ) = @_;
    return 0 unless ( $connection && $message );
    return 0 unless ( $message->any_body =~ m/^workhorse/i );

    my ( $rtext, $jsontext );

    if ( $message->any_body =~ m/^workhorse\s+version\s+(.+)/i ) {
        ( $rtext, $jsontext ) = _list_versions($message);
    }

    return _send_reply( $message, $rtext, $jsontext );
}

=head2 _handler_list($flag)

  Produces a hash of installed handlers

=cut

sub _handler_list {
    my ($flag) = @_;
    $flag = 'all' unless $flag;
    my $config    = Workhorse::Config::object;
    my @loaded    = Workhorse::Handlers->get_loaded;
    my $functions = $config->('functions');
    my %handlers  = ();

    foreach my $mod (@loaded) {
        my $version     = ${"$mod\::VERSION"} | '0.00';
        my $name        = ${"$mod\::NAME"};
        my $description = ${"$mod\::DESCRIPTION"};
        my $active      = 'inactive';
        if ($name) {
            $active = 'active'
              if ( $functions->{$name}
                && $functions->{$name}->{active} eq 'yes' );
        }
        else {
            $active = 'unknown';
        }
        unless ( $flag eq 'all' ) {
            next unless ( $flag eq $active );
        }
        $handlers{$mod}{version}     = $version;
        $handlers{$mod}{active}      = $active;
        $handlers{$mod}{name}        = $name if ($name);
        $handlers{$mod}{description} = $description if ($description);
    }

    return %handlers;
}

=head2 _list_handlers( $message )

  Replies to request for handler list

=cut

sub _list_handlers {
    my ( $message, $request ) = @_;
    my $config = Workhorse::Config::object;

    my $flag = 'all';
    if ( $message->any_body =~ m/^workhorse\s+handlers\s+(\w+)/i ) {
        $flag = lc($1);
    }
    my ( $rtext, $jsontext );
    my %handlers = _handler_list($flag);

    for my $handler ( sort keys %handlers ) {
        $rtext .=
            $handler . ' '
          . $handlers{$handler}{version} . ' '
          . $handlers{$handler}{active} . "\n";
        $rtext .= "\tName: " . $handlers{$handler}{name} . "\n"
          if ( $handlers{$handler}{name} );
        $rtext .= "\tDescription: " . $handlers{$handler}{description} . "\n"
          if ( $handlers{$handler}{description} );
        $rtext .= "\n";
    }
    $rtext = "\n" . $rtext if ($rtext);
    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;
    if ($request) {
        my $id = ( $request->{id} ) ? $request->{id} : time;
        $jsontext = $coder->encode(
            { success => 1, message => '', id => $id, handlers => \%handlers }
        );
    }
    else {
        $jsontext = $coder->encode( \%handlers );
    }
    return ( $rtext, $jsontext );
}

=head2 _gen_versions

	Generate version data

=cut

sub _gen_versions {
    my $mainver = $Workhorse::VERSION | '0.00';

    my %versions = ( 'Workhorse' => $mainver );

    my @loaded = Workhorse->get_loaded;
    foreach my $mod (@loaded) {
        $versions{$mod} = ${"$mod\::VERSION"} | '0.00';
    }

    # Get handler list
    my %handlers = _handler_list('all');

    for my $handler ( keys %handlers ) {
        $versions{$handler} = $handlers{$handler}{version};
    }

    return %versions;

}

=head2 _list_versions( $message )

  Replies to request for version list

=cut

sub _list_versions {
    my ($message) = @_;
    my $module = 'all';
    if ( $message->any_body =~ m/^workhorse\s+version\s+(.+)/i ) {
        $module = lc($1);
    }
    my ( $rtext, $jsontext );

    my %versions        = _gen_versions;
    my %return_versions = ();

    for my $mod ( sort keys %versions ) {
        unless ( $module eq 'all' ) {
            next unless ( lc($module) eq lc($mod) );
        }
        $rtext .= $mod . ' = ' . $versions{$mod} . "\n";
        $return_versions{$mod} = $versions{$mod};
    }

    unless ($rtext) {
        $rtext = "Module $module not found";
    }

    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;
    $jsontext = $coder->encode( \%return_versions );
    $rtext = "\n" . $rtext if ( $module eq 'all' );
    return ( $rtext, $jsontext );
}

=head2 _list_users()

   Replies to request for user list
	
=cut

sub _list_users {
    my ($request) = @_;
    my ( $rtext, $jsontext );
    my $config = Workhorse::Config::object;
    my $users  = $config->('users');

    for my $user ( sort keys %{$users} ) {
        my $access = $users->{$user}->{allowed};
        $access = 'none' unless $access;
        $rtext .= $user . "\n" . "\tAccess: $access\n";
        if ( $access eq 'all' ) {
            $rtext .= "\tFunctions: all\n";
        }
        elsif ( $access eq 'limited' ) {
            if ( $users->{$user}->{functions} ) {
                $rtext .= "\tFunctions:\n";
                for my $function ( sort keys %{ $users->{$user}->{functions} } )
                {
                    $rtext .= "\t\t$function: "
                      . $users->{$user}->{functions}->{$function} . "\n";
                }

            }
            else {
                $rtext .= "\tFunctions: none\n";
            }
        }
        else {
            $rtext .= "\tFunctions: none\n";
        }
    }

    $rtext = "\n" . $rtext if ($rtext);
    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;
    my $jsontext;
    if ($request) {
        my $id = ( $request->{id} ) ? $request->{id} : time;
        $jsontext = $coder->encode(
            { success => 1, message => '', id => $id, users => $users } );
    }
    else {
        $jsontext =
          $coder->encode( { success => 1, message => '', users => $users } );
    }
    return ( $rtext, $jsontext );
}

=head2 _list_handles()

   Replies to request for a list of MUC Handles
	
=cut

sub _list_handles {
    my ($request) = @_;
    my ( $rtext, $jsontext );
    my $config  = Workhorse::Config::object;
    my $handles = $config->('handles');

    for my $handle ( sort keys %{$handles} ) {
        my $link = $handles->{$handle}->{link};
        $rtext .= $handle . "\n" . "\tLinks To: $link\n";
    }

    $rtext = "\n" . $rtext if ($rtext);
    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;

    my $jsontext;
    if ($request) {
        my $id = ( $request->{id} ) ? $request->{id} : time;
        $jsontext = $coder->encode(
            { success => 1, message => '', id => $id, handles => $handles } );
    }
    else {
        $jsontext = $coder->encode(
            { success => 1, message => '', handles => $handles } );
    }
    return ( $rtext, $jsontext );
}

=head2 _admin_add_handler( $message )

   Replies to administrative requests for additions
	
=cut

sub _admin_add_handler {
    my ( $message, $request ) = @_;
    my ( $success, $response );
    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;

    if ($request) {
        if (    $request->{handler} =~ m/^workhorse$/i
            and $request->{command} =~ m/^add$/i )
        {
            if ( $request->{flag} =~ m/^user$/i
                and defined( $request->{username} ) )
            {
                ( $success, $response ) =
                  _admin_add_username( lc( $request->{username} ) );
            }
            elsif ( $request->{flag} =~ m/^handle$/i
                and defined( $request->{handle} )
                and defined( $request->{link} ) )
            {
                ( $success, $response ) =
                  _admin_add_handle( lc( $request->{handle} ),
                    lc( $request->{link} ) );
            }
            elsif ( $request->{flag} =~ m/^access$/i
                and defined( $request->{username} )
                and defined( $request->{handler} ) )
            {
                ( $success, $response ) =
                  _admin_add_access( lc( $request->{username} ),
                    lc( $request->{handler} ) );
            }
        }
    }
    else {
        if ( $message->any_body =~ m/^workhorse\s+add\s+user\s+(.+)/i ) {
            my $username = lc($1);
            ( $success, $response ) = _admin_add_username($username);
        }
        elsif ( $message->any_body =~
            m/^workhorse\s+add\s+handle\s+([^@]+@[^\s]+)\s+(.+)/i )
        {
            my $link   = lc($1);
            my $handle = lc($2);

            ( $success, $response ) = _admin_add_handle( $handle, $link );
        }
        elsif ( $message->any_body =~
            m/^workhorse\s+add\s+access\s+([^@]+@[^\s]+)\s+(.+)/i )
        {
            my $username = lc($1);
            my $handler  = lc($2);

            ( $success, $response ) = _admin_add_access( $username, $handler );
        }
    }

    my $rtext = $response;
    my $jsontext;
    if ($request) {
        my $id = ( $request->{id} ) ? $request->{id} : time;
        $jsontext = $coder->encode(
            { success => $success, message => $response, id => $id } );
    }
    else {
        $jsontext =
          $coder->encode( { success => $success, message => $response } );
    }
    return ( $rtext, $jsontext );
}

=head2 _admin_remove_handler( $message )

   Replies to administrative requests for additions
	
=cut

sub _admin_remove_handler {
    my ( $message, $request ) = @_;
    my ( $success, $response );
    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;

    if ($request) {
        if (    $request->{handler} =~ m/^workhorse$/i
            and $request->{command} =~ m/^remove$/i )
        {
            if ( $request->{flag} =~ m/^user$/i
                and defined( $request->{username} ) )
            {
                ( $success, $response ) =
                  _admin_rm_username( lc( $request->{username} ) );
            }
            elsif ( $request->{flag} =~ m/^handle$/i
                and defined( $request->{handle} ) )
            {
                ( $success, $response ) =
                  _admin_rm_handle( lc( $request->{handle} ) );
            }
            elsif ( $request->{flag} =~ m/^access$/i
                and defined( $request->{username} )
                and defined( $request->{handler} ) )
            {
                ( $success, $response ) =
                  _admin_rm_access( lc( $request->{username} ),
                    lc( $request->{handler} ) );
            }
        }
    }
    else {
        if ( $message->any_body =~ m/^workhorse\s+remove\s+user\s+(.+)/i ) {
            my $username = lc($1);
            ( $success, $response ) = _admin_rm_username($username);
        }
        elsif ( $message->any_body =~ m/^workhorse\s+remove\s+handle\s+(.+)/i )
        {
            my $handle = lc($1);
            ( $success, $response ) = _admin_rm_handle($handle);
        }
        elsif ( $message->any_body =~
            m/^workhorse\s+remove\s+access\s+([^@]+@[^\s]+)\s+(.+)/i )
        {
            my $username = lc($1);
            my $handler  = lc($2);

            ( $success, $response ) = _admin_rm_access( $username, $handler );
        }
    }

    my $rtext = $response;
    my $jsontext;
    if ($request) {
        my $id = ( $request->{id} ) ? $request->{id} : time;
        $jsontext = $coder->encode(
            { success => $success, message => $response, id => $id } );
    }
    else {
        $jsontext =
          $coder->encode( { success => $success, message => $response } );
    }
    return ( $rtext, $jsontext );
}

=head2 _admin_add_username( $username )

   Replies to administrative requests for additions
	
=cut

sub _admin_add_username {
    my ($username) = shift;
    my $config     = Workhorse::Config::object;
    my $users      = $config->('users');
    my ( $success, $response );

    if ($username) {
        if ( $users->{$username} ) {
            $success  = 0;
            $response = 'Username already exists';
        }
        elsif ( $username !~ m/@/ ) {
            $success = 0;
            $response =
              'Username is incorrect, must be in JID format (username@domain)';
        }
        else {
            my $config_dir = $config->{config_dir};
            if ( -d $config_dir . 'users' && -w $config_dir . 'users' ) {
                my $file = $config_dir . 'users/' . $username . '.yml';
                my $user;
                $user->{'allowed'} = 'none';
                DumpFile( $file, $user );
                if ( -f $file ) {
                    chmod( 0664, $file );
                    $success = 1;
                    $config->load_config();
                    $users = $config->('users');
                    if ( $users->{$username} ) {
                        $response =
'User has been added and config successfully reloaded';
                    }
                    else {
                        $response =
                          'User has been added but config has not reloaded';
                    }
                }
                else {
                    $success  = 0;
                    $response = 'Failed to add user';
                }
            }
            else {
                $success = 0;
                $response =
                  'Cannot write to the configuration directory, please correct';
            }
        }
    }
    else {
        $success  = 0;
        $response = 'You must provide the username';
    }
    return ( $success, $response );
}

=head2 _admin_add_handle( $handle, $link )

   Replies to administrative requests for handle additions
	
=cut

sub _admin_add_handle {
    my ( $handle, $link ) = @_;
    my $config  = Workhorse::Config::object;
    my $users   = $config->('users');
    my $handles = $config->('handles');
    my ( $success, $response );

    if ( $handle and $link ) {
        if ( $handles->{$handle} ) {
            $success  = 0;
            $response = 'Handle already exists';
        }
        elsif ( $link !~ m/@/ ) {
            $success = 0;
            $response =
              'Link is incorrect, must be in JID format (username@domain)';
        }
        elsif ( !$users->{$link} ) {
            $success  = 0;
            $response = 'Link must point to a configured user';
        }
        else {
            my $config_dir = $config->{config_dir};
            if ( -d $config_dir . 'handles' && -w $config_dir . 'handles' ) {

                my $file = $config_dir . 'handles/' . $handle . '.yml';
                my $h;
                $h->{'link'} = $link;
                DumpFile( $file, $h );
                if ( -f $file ) {
                    chmod( 0664, $file );
                    $success = 1;
                    $config->load_config();
                    $handles = $config->('handles');
                    if ( $handles->{$handle} ) {
                        $response =
'Handle has been added and config successfully reloaded';
                    }
                    else {
                        $response =
                          'Handle has been added but config has not reloaded';
                    }
                }
                else {
                    $success  = 0;
                    $response = 'Failed to add Handle';
                }
            }
            else {
                $success = 0;
                $response =
                  'Cannot write to the configuration directory, please correct';
            }
        }
    }
    else {
        $success = 0;
        $response =
          'You must provide both the handle and the JID it is linked to';
    }
    return ( $success, $response );
}

=head2 _admin_add_access( $username, $handler )

   Grants username access to specified handler
	
=cut

sub _admin_add_access {
    my ( $username, $handler ) = @_;

    my $config   = Workhorse::Config::object;
    my $users    = $config->('users');
    my %handlers = _handler_list('active');
    my $add_handler;

    my ( $success, $response );

    if ( $username and $handler ) {

        # See if username is valid
        if ( $users->{$username} ) {

# Test if handler is valid, start by determining if user sent camel case or straight name
            my $camel = ( $handler =~ m/::/ ) ? 1 : 0;
            my $valid_handler = 0;
            for my $h ( keys %handlers ) {
                if ( $camel and lc($h) eq lc($handler) ) {
                    $valid_handler = 1;
                    $add_handler   = $handlers{$h}{name};
                    last;
                }
                elsif ( lc($handler) eq $handlers{$h}{name} ) {
                    $valid_handler = 1;
                    $add_handler   = $handlers{$h}{name};
                    last;
                }
            }

            if ($valid_handler) {

                # Locate file and make sure we can write it
                my $config_dir = $config->{config_dir};
                my $file       = $config_dir . 'users/' . $username . '.yml';
                if ( -f $file && -w $file ) {

                    # Load user configuration
                    my $udata = LoadFile($file);

                    # Double check if user already has access
                    if ( $udata->{allowed} eq 'all' ) {
                        $success  = 0;
                        $response = $username
                          . ' is a superuser and already has access to this handler';
                    }
                    elsif ( $udata->{allowed} eq 'limited'
                        and $udata->{functions}->{$add_handler} eq 'allowed' )
                    {
                        $success = 0;
                        $response =
                            $username
                          . ' is already allowed access to the handler '
                          . $add_handler;
                    }
                    else {

                        # Change global allowed to limited
                        $udata->{allowed} = 'limited';
                        $udata->{functions}->{$add_handler} = 'allowed';

                        # Save to file
                        DumpFile( $file, $udata );
                        $success = 1;

                        # Reload config
                        $config->load_config();
                        $users = $config->('users');
                        if ( $users->{$username}->{functions}->{$add_handler} eq
                            'allowed' )
                        {
                            $response =
                                $username
                              . ' has been granted access to '
                              . $add_handler
                              . ' and config has been reloaded';
                        }
                        else {
                            $response =
                                $username
                              . ' has been granted access to '
                              . $add_handler
                              . ' but config has not been reloaded';
                        }
                    }
                }
                else {
                    $success = 0;
                    $response =
                        'Configuration file for '
                      . $username
                      . ' does not exist or is unwriteable';
                }

            }
            else {
                $success  = 0;
                $response = 'Specified handler is not active on this system';
            }
        }
        else {
            $success  = 0;
            $response = 'Username provided does not exist on this system';
        }
    }
    else {
        $success  = 0;
        $response = 'You must provide both the username and the handler';
    }
    return ( $success, $response );
}

=head2 _admin_rm_username ( $username )

   Replies to administrative requests for removals
	
=cut

sub _admin_rm_username {
    my ($username) = shift;
    my $config     = Workhorse::Config::object;
    my $users      = $config->('users');
    my ( $success, $response );

    if ($username) {
        if ( !$users->{$username} ) {
            $success  = 0;
            $response = 'Username does not exist';
        }
        elsif ( $users->{$username}->{allowed} eq 'all' ) {
            $success  = 0;
            $response = 'Can not remove a super user';
        }
        else {
            my $config_dir = $config->{config_dir};
            if ( -d $config_dir . 'users' and -w $config_dir . 'users' ) {
                my $file = $config_dir . 'users/' . $username . '.yml';
                if ( -f $file and -w $file ) {
                    unlink($file);
                    $success = 1;
                    $config->load_config();
                    $users = $config->('users');
                    if ( $users->{$username} ) {
                        $response =
                          'User has been removed but config has not reloaded';
                    }
                    else {
                        $response =
                          'User has been removed and config has been reloaded';
                    }
                }
                else {
                    $success = 0;
                    $response =
'Cannot remove user, expected file does not exist or is not writable';
                }
            }
            else {
                $success = 0;
                $response =
                  'Cannot write to the configuration directory, please correct';
            }
        }
    }
    else {
        $success  = 0;
        $response = 'You must provide the username';
    }
    return ( $success, $response );
}

=head2 _admin_rm_handle ( $handle )

   Removes a handle from the configuration
	
=cut

sub _admin_rm_handle {
    my ($handle) = shift;
    my $config   = Workhorse::Config::object;
    my $handles  = $config->('handles');
    my ( $success, $response );

    if ($handle) {
        if ( !$handles->{$handle} ) {
            $success  = 0;
            $response = 'Handle does not exist';
        }
        else {
            my $config_dir = $config->{config_dir};
            if ( -d $config_dir . 'handles' and -w $config_dir . 'handles' ) {
                my $file = $config_dir . 'handles/' . $handle . '.yml';
                if ( -f $file and -w $file ) {
                    unlink($file);
                    $success = 1;
                    $config->load_config();
                    $handles = $config->('handles');
                    if ( $handles->{$handles} ) {
                        $response =
                          'Handle has been removed but config has not reloaded';
                    }
                    else {
                        $response =
'Handle has been removed and config has been reloaded';
                    }
                }
                else {
                    $success = 0;
                    $response =
'Cannot remove handle, expected file does not exist or is not writable';
                }
            }
            else {
                $success = 0;
                $response =
                  'Cannot write to the configuration directory, please correct';
            }
        }
    }
    else {
        $success  = 0;
        $response = 'You must provide the handle';
    }
    return ( $success, $response );
}

=head2 _admin_rm_access( $username, $handler )

   Revokes username access to specified handler
	
=cut

sub _admin_rm_access {
    my ( $username, $handler ) = @_;

    my $config   = Workhorse::Config::object;
    my $users    = $config->('users');
    my %handlers = _handler_list('active');
    my $rm_handler;

    my ( $success, $response );

    if ( $username and $handler ) {

        # See if username is valid
        if ( $users->{$username} ) {

# Test if handler is valid, start by determining if user sent camel case or straight name
            my $camel = ( $handler =~ m/::/ ) ? 1 : 0;
            my $valid_handler = 0;
            for my $h ( keys %handlers ) {
                if ( $camel and lc($h) eq lc($handler) ) {
                    $valid_handler = 1;
                    $rm_handler   = $handlers{$h}{name};
                    last;
                }
                elsif ( lc($handler) eq $handlers{$h}{name} ) {
                    $valid_handler = 1;
                    $rm_handler   = $handlers{$h}{name};
                    last;
                }
            }

            if ($valid_handler) {

                # Locate file and make sure we can write it
                my $config_dir = $config->{config_dir};
                my $file       = $config_dir . 'users/' . $username . '.yml';
                if ( -f $file && -w $file ) {

                    # Load user configuration
                    my $udata = LoadFile($file);

                    # Double check if user already has access
                    if ( $udata->{allowed} eq 'all' ) {
                        $success  = 0;
                        $response = $username
                          . ' is a superuser and access cannot be removed';
                    }
                    elsif ( ($udata->{allowed} eq 'limited' or $udata->{allowed} eq 'none')
                        and (!$udata->{functions}->{$rm_handler} or $udata->{functions}->{$rm_handler} eq 'none') )
                    {
                        $success = 0;
                        $response =
                            $username
                          . ' does not have access to the handler '
                          . $rm_handler;
                    }
                    else {
						
						# Remove the handler access
						
						delete $udata->{functions}->{$rm_handler};
						
						# If no further functions left, change access to none
						
						unless (keys %{$udata->{functions}}) {
							$udata->{allowed} = 'none';
						}

                        # Save to file
                        DumpFile( $file, $udata );
                        $success = 1;

                        # Reload config
                        $config->load_config();
                        $users = $config->('users');
                        if (! $users->{$username}->{functions}->{$rm_handler})
                        {
                            $response =
                                $username
                              . ' has had their access to '
                              . $rm_handler
                              . ' removed and config has been reloaded';
                        }
                        else {
                            $response =
                                $username
                              . ' has had their access to '
                              . $rm_handler
                              . ' removed but config has not been reloaded';
                        }
                    }
                }
                else {
                    $success = 0;
                    $response =
                        'Configuration file for '
                      . $username
                      . ' does not exist or is unwriteable';
                }

            }
            else {
                $success  = 0;
                $response = 'Specified handler is not active on this system';
            }
        }
        else {
            $success  = 0;
            $response = 'Username provided does not exist on this system';
        }
    }
    else {
        $success  = 0;
        $response = 'You must provide both the username and the handler';
    }
    return ( $success, $response );
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) or croak "$self is not an object";
    my $name = $AUTOLOAD;
    $name =~ s/.*://;    # strip fully-qualified portion
    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub DESTROY {

}

=head1 AUTHOR

Derek Buttineau, <derek@csolve.net>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
