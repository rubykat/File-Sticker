package File::Sticker;

=head1 NAME

File::Sticker - Read, Write file meta-data

=head1 SYNOPSIS

    use File::Sticker;

    my $obj = File::Sticker->new(%args);

=head1 DESCRIPTION

This will read and write meta-data from files, in a standardized manner.
And update a database with that information.

=cut

use common::sense;
use File::Sticker::Reader;
use Module::Pluggable instantiate => 'new',
search_path => ['File::Sticker::Reader'],
sub_name => 'readers';
use Module::Pluggable instantiate => 'new',
search_path => ['File::Sticker::Writer'],
sub_name => 'writers';

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = File::Sticker->new();

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    # ---------------------------------------
    # Readers
    # find out what readers are available
    $self->{read_pri} = {};
    my @readers = $self->readers();
    foreach my $fe (@readers)
    {
	my $priority = $fe->priority();
	my $name = $fe->name();
	if ($self->{debug})
	{
	    print STDERR "reader=$name($priority)\n";
	}
	if (!exists $self->{read_pri}->{$priority})
	{
	    $self->{read_pri}->{$priority} = [];
	}
	push @{$self->{read_pri}->{$priority}}, $fe;
    }

    return ($self);
} # new

=head2 read_meta

    my %info = $fs->read_meta(filename=>$filename);

=cut
sub read_meta ($%) {
    my $self = shift;
    my %args = (
	filename=>undef,
	@_
    );

    my $reader;
    my $first_url = $args{urls}[0];
    foreach my $pri (reverse sort keys %{$self->{read_pri}})
    {
	foreach my $fe (@{$self->{read_pri}->{$pri}})
	{
	    if ($fe->allow($first_url))
	    {
		$reader = $fe;
		warn "reader($pri): ", $fe->name(), "\n" if $args{verbose};
		last;
	    }
	}
	if (defined $reader)
	{
	    last;
	}
    }
    if (defined $reader)
    {
	$reader->init(%{$self});
	return $reader->read(%args);
    }

    return undef;
} # read_meta

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__
