package Workhorse::Functions::QSumm;

use strict;
use Carp;
our $VERSION = "0.01";
our $AUTOLOAD;

=head1 NAME

Workhorse::Functions::QSumm

=head2 DESCRIPTION

Allows queries to the queue summary

=head1 METHODS

=cut

=head2 new

  Constructor

=cut

our $NAME        = 'qsumm';
our $DESCRIPTION = 'Allows queries to the queue summary';

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
    $self->{chat} = \&_return_info;
    return $self;
}

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

sub _return_info {
    my ( $connection, $message ) = @_;
    return 0 unless ( $connection && $message );
    my $qsumm = `/usr/bin/mailq | /usr/local/sbin/exiqsumm`;
    my $rtext;
    my $jsontext;
    my %queue_data = ();
    my %time_vals  = (
        d => 'days',
        h => 'hours',
        m => 'minutes',
        s => 'seconds',
    );
    foreach my $line ( ( split( /\n/, $qsumm ) ) ) {

        if ( $line =~ m/([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+TOTAL/ ) {
            $queue_data{total}{number} = $1;
            $queue_data{total}{size}   = $2;
            $queue_data{total}{oldest} = $3;
            $queue_data{total}{newest} = $4;
        }
        elsif ( $line =~ m/(\d+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+(.+)$/ ) {
            $queue_data{ lc($5) }{number} = $1;
            $queue_data{ lc($5) }{size}   = $2;
            $queue_data{ lc($5) }{oldest} = $3;
            $queue_data{ lc($5) }{newest} = $4;
        }
    }
    my $reply = $message->make_reply;
    my $response;
    if ( $message->body('json') ) {
        my $coder   = JSON::XS->new->utf8->pretty->allow_nonref;
        my $request = $coder->decode( $message->body('json') );

        if ( $request->{handler} =~ m/^qsumm$/i ) {
            if ( $request->{command} ) {
                if ( $queue_data{ lc( $request->{command} ) } ) {
                    ( $rtext, $jsontext ) = (
                        'Yes, there are '
                          . $queue_data{ lc( $request->{command} ) }{number}
                          . ' messages queued for '
                          . lc( $request->{command} )
                          . ' totalling '
                          . $queue_data{ lc( $request->{command} ) }{size},
                        $coder->encode(
                            {
                                number =>
                                  $queue_data{ lc( $request->{command} ) }
                                  {number},
                                size => $queue_data{ lc( $request->{command} ) }
                                  {size},
                                oldest =>
                                  $queue_data{ lc( $request->{command} ) }
                                  {oldest},
                                newest =>
                                  $queue_data{ lc( $request->{command} ) }
                                  {newest}
                            }
                        )
                    );
                }
            }
            else {
				$queue_data{id} = $request->{id};
                ( $rtext, $jsontext ) = ( $qsumm, $coder->encode( \%queue_data ) );
            }
        }
        else { return 0; }
    }
    elsif ( $message->any_body =~ m/^qsumm\s+([\w\.\-]+)$/i ) {
		my $domain = $1;
        if ( $queue_data{ lc($domain) } ) {
            my $age    = 0;
            my $oldest = $queue_data{ lc($domain) }{oldest};
            if ( $oldest =~ m/^(\d+)(d|h|m|s)/i ) {
                $age = $1 . ' ' . $time_vals{$2};
            }
			use Data::Dumper;
            $rtext =
                'Yes, there are '
              . $queue_data{ lc($domain) }{number}
              . ' messages queued for '
              . lc($domain)
              . ' totalling '
              . $queue_data{ lc($domain) }{size}
              . ' and queuing for a total time of '
              . $age;
        }
        else {
            $rtext = 'No, domain is not queueing mail';
        }
    }
    elsif ( $message->any_body =~ m/^qsumm/i ) { $rtext = $qsumm; }
    else                                       { return 0 }

    return _send_reply( $message, $rtext, $jsontext );
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

Created by Derek on 2007-08-07.
Copyright (c) 2007 Compu-SOLVE Technologies, Inc. All rights reserved.

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
