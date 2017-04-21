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
use Hash::Merge;
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

    if (!exists $self->{fields_wanted})
    {
        # use default
        $self->{fields_wanted} = {
            file => 'TEXT',
            title => 'TEXT',
            description => 'TEXT',
            url => 'TEXT',
            date => 'TEXT',
            creator => 'TEXT',
            tags => 'MULTI',
        };
    }
    # -------------------------------------
    # Readers
    my @readers = $self->readers();
    foreach my $rd (@readers)
    {
	$rd->init(fields_wanted=>$self->{fields_wanted});
    }

    # -------------------------------------
    # Writers
    my @writers = $self->writers();
    foreach my $wt (@writers)
    {
	$wt->init(fields_wanted=>$self->{fields_wanted});
    }

    return ($self);
} # new

=head2 read_meta

This will read the meta-data from the file, using all possible ways.

    my $info = $fs->read_meta(filename=>$filename);

=cut
sub read_meta ($%) {
    my $self = shift;
    my %args = (
	filename=>undef,
	@_
    );
    my $filename = $args{filename};

    if (!-r $filename)
    {
        return undef;
    }

    my $merge = Hash::Merge->new();
    my $meta = {};
    foreach my $reader (@{$self->readers()})
    {
        if ($reader->allow($filename))
        {
            my $info = $reader->read_meta($filename);
            my $newmeta = $merge->merga($meta, $info);
            $meta = $newmeta;
        }
    }

    return $meta;
} # read_meta

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__
