package File::Sticker::Reader;

=head1 NAME

File::Sticker::Reader - read and standardize meta-data from files

=head1 SYNOPSIS

    use File::Sticker::Reader;

    my $obj = File::Sticker::Reader->new(%args);

    my %meta = $obj->read_meta(%args);

=head1 DESCRIPTION

This will read meta-data from files in various formats, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

The standard nomenclature is:

=over

=item url

The source URL of this file (ref 'dublincore.source')

=item creator

The author or artist who created this. (ref 'dublincore.creator')

=item title

The title of the item. (ref 'dublincore.title')

=item description

The description of the item. (ref 'dublincore.description')

=item tags

The item's tags. (ref 'Keywords').

=back

Other fields will be called whatever the user has pre-configured.

=cut

use common::sense;
use File::LibMagic;
use Path::Tiny;
use POSIX qw(strftime);

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = File::Sticker::Reader->new();

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    return ($self);
} # new

=head2 init

Initialize the object.
Set which fields you are interested in ('wanted_fields').

    $reader->init(wanted_fields=>{title=>'TEXT',count=>'NUMBER',tags=>'MULTI'});

=cut

sub init {
    my $self = shift;
    my %parameters = @_;

    foreach my $key (keys %parameters)
    {
	$self->{$key} = $parameters{$key};
    }
    $self->{file_magic} = File::LibMagic->new();
} # init

=head2 name

The name of the reader; this is basically the last component
of the module name.  This works as either a class function or a method.

$name = $self->name();

$name = File::Sticker::Reader::name($class);

=cut

sub name {
    my $class = shift;
    
    my $fullname = (ref ($class) ? ref ($class) : $class);

    my @bits = split('::', $fullname);
    return pop @bits;
} # name

=head2 allow

If this reader can be used for the given file, and the wanted_fields then this returns true.
Returns false if there are no 'wanted_fields'!

    if ($reader->allow($file))
    {
	....
    }

=cut

sub allow {
    my $self = shift;
    my $file = shift;

    my $okay = $self->allowed_file($file);
    if ($okay) # okay so far
    {
        if (exists $self->{wanted_fields}
                and defined $self->{wanted_fields})
        {
            # the known fields must be a subset of the wanted fields
            my $known_fields = $self->known_fields();
            foreach my $fn (keys %{$self->{wanted_fields}})
            {
                if (!exists $known_fields->{$fn}
                        or !defined $known_fields->{$fn}
                        or !$known_fields->{$fn})
                {
                    $okay = 0;
                    last;
                }
            }
        }
        else
        {
            $okay = 0;
        }
    }
    return $okay;
} # allow

=head2 allowed_file

If this reader can be used for the given file, then this returns true.
This must be overridden by the specific reader class.

    if ($reader->allowed_file($file))
    {
	....
    }

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this reader knows about.

This must be overridden by the specific reader class.

    my $known_fields = $reader->known_fields();

=cut

sub known_fields {
    my $self = shift;

    return undef;
} # known_fields

=head2 read_meta

Read the meta-data from the given file.

This must be overridden by the specific reader class.

    my $meta = $reader->read_meta(filename=>$filename);

=cut

sub read_meta {
    my $self = shift;
    my %args = @_;

} # read_meta

=head1 Helper Functions

Private interface

=head2 derive_values

Derive common values from the existing meta-data.

    $reader->derive_values(filename=>$filename,
        meta=>$meta);

=cut

sub derive_values {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};
    my $meta = $args{meta};

    my $fp = path($filename);
    $meta->{file} = $fp->realpath->stringify;
    $meta->{basename} = $fp->basename->stringify;
    $meta->{name} = $fp->basename(qr/\.\w+/)->stringify;
    if ($self->{topdir})
    {
        $meta->{relpath} = $fp->relative($self->{topdir})->stringify;

        # Make this grouping stuff simple:
        # take it as the *directory* where the file is;
        # this is because that's how it is *grouped* together with other files, yes?
        # But use the directory relative to the "top" directory, the first two or three parts of it.

        my $dir = $fp->relative($self->{topdir})->parent->stringify;
        $dir =~ s!^/!!; # remove the leading /
        my @bits = split(/\//, $dir);
        splice(@bits,3);
        $meta->{grouping} = join(' ', @bits);
    }
    my $stat = $fp->stat;
    $meta->{filedate} = strftime '%Y-%m-%d %H:%M:%S', localtime $stat->mtime;
    $meta->{filesize} = $stat->size;

    $meta->{alt_title} = $meta->{title} if !$meta->{alt_title};
    return $meta;
} # derive_values

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Reader
__END__
