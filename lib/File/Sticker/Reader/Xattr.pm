package File::Sticker::Reader::Xattr;

=head1 NAME

File::Sticker::Reader::Xattr - read and standardize meta-data from ExtAttr file

=head1 SYNOPSIS

    use File::Sticker::Reader::Xattr;

    my $obj = File::Sticker::Reader::Xattr->new(%args);

    my %meta = $obj->read_meta(%args);

=head1 DESCRIPTION

This will read meta-data from extended user attributes of files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use File::ExtAttr ':all';

use parent qw(File::Sticker::Reader);

=head1 METHODS

=head2 allowed_file

If this reader can be used for the given file, then this returns true.
This can be used with any file, if the filesystem supports extended attributes.
I don't know how to test for that, so I'll just assume "yes".

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    if (-f $file)
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this reader knows about.
This reader has no limitations.

    my $known_fields = $reader->known_fields();

=cut

sub known_fields {
    my $self = shift;

    if ($self->{wanted_fields})
    {
        return $self->{wanted_fields};
    }
    return {};
} # known_fields

=head2 read_meta

Read the meta-data from the given file.

    my $meta = $obj->read_meta(filename=>$filename);

=cut

sub read_meta {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};

    my %meta = ();
    foreach my $key (listfattr($filename))
    {
        if ($key eq 'dublincore.source' or $key eq 'xdg.referrer.url')
        {
            $meta{url} = getfattr($filename, $key);
        }
        elsif ($key eq 'dublincore.creator')
        {
            $meta{creator} = getfattr($filename, $key);
        }
        elsif ($key eq 'dublincore.title')
        {
            $meta{title} = getfattr($filename, $key);
        }
        elsif ($key eq 'dublincore.alternative')
        {
            $meta{alt_title} = getfattr($filename, $key);
        }
        elsif ($key eq 'dublincore.description')
        {
            $meta{description} = getfattr($filename, $key);
        }
        else
        {
            $meta{$key} = getfattr($filename, $key);
        }
    }

    return \%meta;
} # read_meta

=cut

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Reader
__END__
