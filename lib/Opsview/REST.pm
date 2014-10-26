package Opsview::REST;
{
  $Opsview::REST::VERSION = '0.006';
}

use Moo;
use namespace::autoclean;

use Carp;
use Opsview::REST::Config;
use Opsview::REST::Exception;

with 'Opsview::REST::APICaller';

has [qw/ user base_url /] => (
    is       => 'ro',
    required => 1,
);

has [qw/ pass auth_tkt /] => (
    is  => 'ro',
);

{
    # install methods in the namespace for configurable objects
    my @config_objects = qw/
        contact host role servicecheck hosttemplate attribute timeperiod
        hostgroup servicegroup notificationmethod hostcheckcommand keyword
        monitoringserver
    /;

    for my $obj_type (@config_objects) {
        no strict 'refs';

        my $general_url = Opsview::REST::Config->new($obj_type);

        # Single object get (get_contact, get_host, ...)
        # URL: /rest/config/{object_type}/{id}
        # GET - get object details
        *{__PACKAGE__ . "::get_$obj_type"} = sub {
            my $self = shift;
            my $id   = shift;
            croak "Required id" unless defined $id;

            my $uri = Opsview::REST::Config->new($obj_type, $id);
            return $self->get($uri->as_string);
        };

        # Multiple object get (get_contacts, get_hosts, ...)
        # URL: /rest/config/{object_type}
        # GET - list object type. Can pass in search attributes
        *{__PACKAGE__ . '::get_' . $obj_type . 's'} = sub {
            my $self = shift;
            require JSON::XS;
            my $uri = Opsview::REST::Config->new(
                $obj_type,
                json_filter => JSON::XS::encode_json {@_},
            );
            return $self->get($uri->as_string);

        };

        # Create object
        # URL: /rest/config/{object_type}
        # POST - add a new object or a list of object type
        *{__PACKAGE__ . "::create_$obj_type"} = sub {
            my $uri = Opsview::REST::Config->new($obj_type);
            return shift->post($uri->as_string, { @_ });
        };

        # Clone object
        # URL: /rest/config/{object_type}/{id}
        # POST - clone this object with merged incoming data to create
        # new object
        *{__PACKAGE__ . "::clone_$obj_type"} = sub {
            my $self = shift;
            my $id   = shift;
            croak "Required id" unless defined $id;

            my $uri = Opsview::REST::Config->new($obj_type, $id);
            return $self->post($uri->as_string, { @_ });
        };

        # Create or update
        # URL: /rest/config/{object_type}
        # PUT - create or update (based on unique keys) object or a list
        # of objects
        *{__PACKAGE__ . "::create_or_update_$obj_type"} = sub {
            my $uri = Opsview::REST::Config->new($obj_type);
            return shift->put($uri->as_string, { @_ });
        };

        # Update
        # URL: /rest/config/{object_type}/{id}
        # PUT - update this object's details
        *{__PACKAGE__ . "::update_$obj_type"} = sub {
            my $self = shift;
            my $id   = shift;
            croak "Required id" unless defined $id;

            my $uri = Opsview::REST::Config->new($obj_type, $id);
            return $self->put($uri->as_string, { @_ });
        };

        # Delete
        # URL: /rest/config/{object_type}/{id}
        # DELETE - delete object
        *{__PACKAGE__ . "::delete_$obj_type"} = sub {
            my $self = shift;
            my $id   = shift;
            croak "Required id" unless defined $id;

            my $uri = Opsview::REST::Config->new($obj_type, $id);
            return $self->delete($uri->as_string, { @_ });
        };
    }
}

sub BUILD {
    my ($self) = @_;
    
    my $r;
    if (defined $self->pass) {
        $r = $self->post('/login', {
            username => $self->user,
            password => $self->pass,
        });

    } elsif (defined $self->auth_tkt) {
        $self->headers->{'Cookie'} = 'auth_tkt=' . $self->auth_tkt . ';';
        $r = $self->post('/login_tkt', { username => $self->user });

        # Clean the cookie as this is not required anymore
        delete $self->headers->{'Cookie'};

    } else {
        croak "Need either a pass or an auth_tkt";
    }

    $self->headers->{'X-Opsview-Username'} = $self->user;
    $self->headers->{'X-Opsview-Token'}    = $r->{token};

}

# Status
sub status {
    my $self = shift;

    require Opsview::REST::Status;
    my $uri = Opsview::REST::Status->new(@_);

    return $self->get($uri->as_string);
}

# Event
sub events {
    my $self = shift;

    require Opsview::REST::Event;
    my $uri = Opsview::REST::Event->new(@_);

    return $self->get($uri->as_string);
}

# Downtime
sub _downtime {
    my $self = shift;

    require Opsview::REST::Downtime;
    my $uri = Opsview::REST::Downtime->new(@_);

    return $uri->as_string;
}

sub downtimes {
    my $self = shift;
    return $self->get($self->_downtime(@_));
}

sub create_downtime {
    my $self = shift;
    return $self->post($self->_downtime(@_));
}

sub delete_downtime {
    my $self = shift;
    return $self->delete($self->_downtime(@_));
}

# Reload
sub reload {
    my $self = shift;
    return $self->post('/reload');
}

sub reload_info {
    my $self = shift;
    return $self->get('/reload');
}

# Acknowledge
sub _ack {
    my $self = shift;

    require Opsview::REST::Acknowledge;
    my $uri = Opsview::REST::Acknowledge->new(@_);

    return $uri->as_string;
}

sub acknowledge_list {
    my $self = shift;
    return $self->get($self->_ack(@_));
}

sub acknowledge {
    my $self = shift;
    return $self->post($self->_ack(@_));
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=pod

=head1 NAME
    
Opsview::REST - Interface to the Opsview REST API

=head1 SYNOPSIS

    use Opsview::REST;

    my $ops = Opsview::REST->new(
        base_url => 'http://opsview.example.com/rest',
        user     => 'username',
        pass     => 'password',
    );

    # These are equivalent
    my $status = $ops->get('/status/hostgroup?hostgroupid=1&...');
    my $status = $ops->status(
        'hostgroup',
        'hostgroupid' => [1, 2],
        'filter'      => 'unhandled',
        ...
    );

    # Configuration methods
    my $host1 = $ops->create_host(
        ip                  => '192.168.0.1',
        name                => 'monitoring-slave',
        hostgroup           => { name => 'Monitoring Servers' },
        notification_period => { name => '24x7' },
    );

    $ops->clone_host(
        $host1->{object}->{id},
        name => 'another-host',
        ip   => '192.168.0.2',
    );

    # Reload it after config
    $ops->reload;

=head1 DESCRIPTION

Opsview::REST is a set of modules to access the Opsview REST API, which is the
recommended method for scripting configuration changes or any other form of
integration since version 3.9.0

=head1 METHODS

=head2 new

Return an instance of the Opsview::REST.

=head3 Required Arguments

=over 4

=item base_url

Base url where the REST API resides. By default it is under C</rest>.

=item user

Username to login as.

=back

=head3 Other Arguments

=over 4

=item pass

=item auth_tkt

Either the pass or the auth_tkt MUST be passed. It will die horribly if none
of these are found.

=back

=head2 get($url)

Makes a "GET" request to the API. The response is properly deserialized and
returned as a Perl data structure.

=head2 status( $endpoint, [ %args ] )

Convenience method to request the "status" part of the API. C<$endpoint> is
the endpoint to send the query to. C<%args> is a hash which will get properly
translated to URL arguments.

More info: L<http://docs.opsview.com/doku.php?id=opsview-community:restapi:status>

=head2 downtimes

=head2 create_downtime( %args )

=head2 delete_downtime( [ %args ] )

Downtime related methods.

More info: L<http://docs.opsview.com/doku.php?id=opsview-community:restapi:downtimes>

=head2 events( [ %args ] )

Get events. An event is considered to be either:

=over 4

=item *

a host or service changing state

=item *

a host or service result during soft failures

=item *

a host or service in a failure state where 'alert every failure' is enabled

=back

More info: L<http://docs.opsview.com/doku.php?id=opsview-community:restapi:event>

=head2 acknowledge( [ %args ] )

Acknowledge problems.

More info: L<http://docs.opsview.com/doku.php?id=opsview-community:restapi:acknowledge>

=head2 acknowledge_list

Lists the problems which the current logged in user has permission to acknowledge.

=head2 reload

Initiates a synchronous reload. Be careful: if your opsview reload takes more
than 60 seconds to run, this call will time out. The returned data contains
the info of the reload.

More info: L<http://docs.opsview.com/doku.php?id=opsview-community:restapi#initiating_an_opsview_reload>

=head2 reload_info

Get status of reload.

More info: L<http://docs.opsview.com/doku.php?id=opsview-community:restapi#initiating_an_opsview_reload>

=head2 get_*

=head2 create_*

=head2 clone_*

=head2 update_*

=head2 delete_*

This methods will be generated for the following types of objects: C<contact>,
C<role>, C<servicecheck>, C<hosttemplate>, C<attribute>, C<timeperiod>,
C<hostgroup>, C<servicegroup>, C<notificationmethod>, C<hostcheckcommand>,
C<keyword>, C<monitoringserver>.

They all, except C<create>, require the object's id. Additionally, C<create>,
C<clone> and C<update> accept a list of key-value pairs.

More info: L<http://docs.opsview.com/doku.php?id=opsview3.14:restapi:config>

=head1 TODO

Document and test configuration methods to handle sets of objects.

=head1 SEE ALSO

=over 4

=item *

L<http://www.opsview.org/>

=item *

L<Opsview REST API Documentation|http://docs.opsview.com/doku.php?id=opsview-community:restapi>

=back

=head1 AUTHOR

=over 4

=item *

Miquel Ruiz <mruiz@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Miquel Ruiz.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=cut


