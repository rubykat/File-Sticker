package File::Sticker::Reader::Gif;

=head1 NAME

File::Sticker::Reader::Gif - read and standardize meta-data from GIF file

=head1 SYNOPSIS

    use File::Sticker::Reader::Gif;

    my $obj = File::Sticker::Reader::Gif->new(%args);

    my %meta = $obj->read_meta($filename);

=head1 DESCRIPTION

This will read meta-data from GIF files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use v5.10;
use common::sense;
use Carp;
use File::LibMagic;
use Image::ExifTool qw(:Public);
use YAML::Any;
use File::Spec;

use parent qw(File::Sticker::Reader);

# FOR DEBUGGING
=head1 DEBUGGING

=head2 whoami

Used for debugging info

=cut
sub whoami  { ( caller(1) )[3] }

=head1 METHODS

=head2 priority

The priority of this reader.  Readers with higher priority get tried first.

=cut

sub priority {
    my $class = shift;
    return 2;
} # priority

=head2 allowed_file

If this reader can be used for the given file, then this returns true.
File must be a GIF image.

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;
    say STDERR whoami(), " filename=$file" if $self->{verbose} > 2;

    $file = $self->_get_the_real_file(filename=>$file);
    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} eq 'image/gif')
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this reader knows about.

    my $known_fields = $reader->known_fields();

=cut

sub known_fields {
    my $self = shift;

    return {
        date=>'TEXT',
        filesize=>'TEXT',
        imagesize=>'TEXT',
        imageheight=>'NUMBER',
        imagewidth=>'NUMBER',
        megapixels=>'NUMBER',
        %{$self->{wanted_fields}},
    };
} # known_fields

=head2 read_meta

Read the meta-data from the given file.

    my $meta = $obj->read_meta($filename);

=cut

sub read_meta {
    my $self = shift;
    my $filename = shift;
    say STDERR whoami(), " filename=$filename" if $self->{verbose} > 2;

    my $filename = $self->_get_the_real_file($filename);
    my $info = ImageInfo($filename);
    my %meta = ();

    # There are multiple fields which could be used as a file date.
    # Check through them until you find a non-empty one.
    my $date = '';
    foreach my $field (qw(CreateDate DateTimeOriginal Date PublishedDate PublicationDate))
    {
        if (exists $info->{$field} and $info->{$field} and !$date)
        {
            $date = $info->{$field};
        }
    }
    $meta{date} = $date if $date;

    # There are SOOOOOO many fields in EXIF data, just remember a subset of them
    foreach my $field (qw(
FileSize
ImageHeight
ImageSize
ImageWidth
Megapixels
))
    {
        if (exists $info->{$field} and $info->{$field})
        {
            $meta{lc($field)} = $info->{$field};
        }
    }

    # -------------------------------------------------
    # Freeform Fields
    # These are stored as YAML data in the Comment field.
    # -------------------------------------------------
    if (exists $info->{Comment} and $info->{Comment})
    {
        say STDERR "Comment=", $info->{Comment} if $self->{verbose} > 2;
        my $data;
        eval {$data = Load($info->{Comment});};
        if ($@)
        {
            warn __PACKAGE__, " Load of YAML data failed: $@";
        }
        elsif (!$data)
        {
            warn __PACKAGE__, " no legal YAML";
        }
        else # okay
        {
            foreach my $field (sort keys %{$data})
            {
                $meta{$field} = $data->{$field};
            }
        }
    }

    return \%meta;
} # read_meta

=head2 _get_the_real_file

If the file is a soft link, look for the file it is pointing to
(because ExifTool behaves badly with soft links).

    my $real_file = $writer->_get_the_real_file(filename=>$filename);

=cut

sub _get_the_real_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    # ExifTool has a wicked habit of replacing soft-linked files with the
    # contents of the file rather than honouring the link.  While using the
    # exiftool script offers -overwrite_original_in_place to deal with this,
    # the Perl module does not appear to have such an option available.

    # So the way to get around this is to check if the file is a soft link, and
    # if it is, find the real file, and write to that. And if *that* file is
    # a soft link... go down the rabbit-hole as deep as it goes.

    while (-l $filename)
    {
        my $realfile = readlink $filename;
        if (-f $realfile)
        {
            $filename = $realfile;
        }
        else # give up and die
        {
            croak "$args{filename} is soft link, cannot find $realfile";
        }
    }

    return $filename;
} # _get_the_real_file

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Reader::Gif
__END__
