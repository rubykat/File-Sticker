package File::Sticker::Scribe::Gif;

=head1 NAME

File::Sticker::Scribe::Gif - read, write and standardize meta-data from GIF file

=head1 SYNOPSIS

    use File::Sticker::Scribe::Gif;

    my $obj = File::Sticker::Scribe::Gif->new(%args);

    my %meta = $obj->read_meta($filename);

    $obj->write_meta(%args);

=head1 DESCRIPTION

This will read and write meta-data from GIF files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use v5.10;
use common::sense;
use Carp;
use File::LibMagic;
use Image::ExifTool qw(:Public);
use YAML::Any;
use File::Spec;

use parent qw(File::Sticker::Scribe);

# FOR DEBUGGING
=head1 DEBUGGING

=head2 whoami

Used for debugging info

=cut
sub whoami  { ( caller(1) )[3] }

=head1 METHODS

=head2 priority

The priority of this scribe.  Scribes with higher priority get tried first.

=cut

sub priority {
    my $class = shift;
    return 2;
} # priority

=head2 allowed_file

If this scribe can be used for the given file, then this returns true.
File must be a GIF image.

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;
    say STDERR whoami(), " file=$file" if $self->{verbose} > 2;

    $file = $self->_get_the_real_file(filename=>$file);
    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} eq 'image/gif')
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this scribe knows about.
This scribe has no limitations, because all the fields are freeform fields.

    my $known_fields = $scribe->known_fields();

=cut

sub known_fields {
    my $self = shift;

    if ($self->{wanted_fields})
    {
        return $self->{wanted_fields};
    }
    return {};
} # known_fields

=head2 readonly_fields

Returns the fields which this scribe knows about, which can't be overwritten,
but are allowed to be "wanted" fields. Things like file-size etc.

    my $readonly_fields = $scribe->readonly_fields();

=cut

sub readonly_fields {
    my $self = shift;

    return {
        date=>'TEXT',
        filesize=>'NUMBER',
        imagesize=>'TEXT',
        imageheight=>'NUMBER',
        imagewidth=>'NUMBER',
        megapixels=>'NUMBER'};
} # readonly_fields

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

    # There are SOOOOOO many fields in image data, just remember a subset of them
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

=head2 delete_field_from_file

Completely remove the given field. This does no checking.

    $scribe->delete_field_from_file(filename=>$filename,field=>$field);

=cut

sub delete_field_from_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " field=$args{field}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $field = $args{field};

    my $fdata = $self->_load_meta($filename);
    if (exists $fdata->{$field})
    {
        delete $fdata->{$field};
        $self->_write_meta(filename=>$filename,meta=>$fdata);
    }

} # delete_field_from_file

=head2 replace_all_meta

Overwrite the existing meta-data with that given.

(This supercedes the parent method because we can do it more efficiently this way)

    $scribe->replace_all_meta(filename=>$filename,meta=>\%meta);

=cut

sub replace_all_meta {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    $self->_write_meta(%args);
    
} # replace_all_meta

=head2 replace_one_field

Overwrite the given field. This does no checking.

    $scribe->replace_one_field(filename=>$filename,field=>$field,value=>$value);

=cut

sub replace_one_field {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " field=$args{field},value=$args{value}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $field = $args{field};
    my $value = $args{value};

    my $info = $self->_load_meta($filename);
    $info->{$field} = $value;
    $self->_write_meta(filename=>$filename,meta=>$info);

} # replace_one_field

=head1 Helper Functions

Private interface.

=head2 _load_meta

Quick non-checking loading of the meta-data. Does not standardize any fields.

    my $meta = $self->_load_meta($filename);

=cut
sub _load_meta {
    my $self = shift;
    my $filename = shift;
    say STDERR whoami(), " filename=$filename" if $self->{verbose} > 2;

    $filename = $self->_get_the_real_file(filename=>$filename);
    my $et = new Image::ExifTool;
    $et->Options(ListSep=>',',ListSplit=>',');
    $et->ExtractInfo($filename);
    my $yaml_str = $et->GetValue('Comment');
    my $meta;
    eval {$meta = Load($yaml_str);};
    if ($@)
    {
        warn __PACKAGE__, " Load of data failed: $@";
        return {};
    }
    if (!$meta)
    {
        warn __PACKAGE__, " no legal YAML";
        return {};
    }
    return $meta;
} # _load_meta

=head2 _write_meta

Write the meta-data as YAML data in the Comment field.
This overwrites whatever is there, it does not check.
This saves multi-value comma-separated fields as arrays.

    $self->_write_meta(meta=>\%meta,filename=>$filename);

=cut
sub _write_meta {
    my $self = shift;
    my %args = @_;

    my $filename = $self->_get_the_real_file(filename=>$args{filename});
    my $meta = $args{meta};
    my $et = new Image::ExifTool;
    $et->Options(ListSep=>',',ListSplit=>',');
    $et->ExtractInfo($filename);

    # restore multi-value comma-separated fields to arrays
    foreach my $fn (keys %{$self->{wanted_fields}})
    {
        if ($self->{wanted_fields}->{$fn} eq 'MULTI'
                and exists $meta->{$fn}
                and defined $meta->{$fn}
                and $meta->{$fn} =~ /,/)
        {
            my @vals = split(/,/, $meta->{$fn});
            $meta->{$fn} = \@vals;
        }
    }
    my $yaml_str = Dump($meta);
    say STDERR "yaml_str=$yaml_str" if $self->{verbose} > 2;
    my $success = $et->SetNewValue('Comment', $yaml_str);
    if ($success)
    {
        $et->WriteInfo($filename);
    }

} # _write_meta

=head2 _get_the_real_file

If the file is a soft link, look for the file it is pointing to
(because ExifTool behaves badly with soft links).

    my $real_file = $scribe->_get_the_real_file(filename=>$filename);

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

1; # End of File::Sticker::Scribe::Gif
__END__
