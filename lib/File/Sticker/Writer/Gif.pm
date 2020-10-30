package File::Sticker::Writer::Gif;

=head1 NAME

File::Sticker::Writer::Gif - write and standardize meta-data from GIF file

=head1 SYNOPSIS

    use File::Sticker::Writer::Gif;

    my $obj = File::Sticker::Writer::Gif->new(%args);

    my %meta = $obj->write_meta(%args);

=head1 DESCRIPTION

This will write meta-data from EXIF files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use Image::ExifTool qw(:Public);
use YAML::Any;

use parent qw(File::Sticker::Writer);

# FOR DEBUGGING
=head1 DEBUGGING

=head2 whoami

Used for debugging info

=cut
sub whoami  { ( caller(1) )[3] }

=head1 METHODS

=head2 priority

The priority of this writer.  Writers with higher priority get tried first.

=cut

sub priority {
    my $class = shift;
    return 2;
} # priority

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
File must be a GIF image.

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;
    say STDERR whoami(), " file=$file" if $self->{verbose} > 2;

    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} eq 'image/gif')
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this writer knows about.
This writer has no limitations.

    my $known_fields = $writer->known_fields();

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

Returns the fields which this writer knows about, which can't be overwritten,
but are allowed to be "wanted" fields. Things like file-size etc.

    my $readonly_fields = $writer->readonly_fields();

=cut

sub readonly_fields {
    my $self = shift;

    return {
        date=>'TEXT',
        filesize=>'TEXT',
        imagesize=>'TEXT',
        imageheight=>'NUMBER',
        imagewidth=>'NUMBER',
        megapixels=>'NUMBER'};
} # readonly_fields

=head2 delete_field_from_file

Completely remove the given field. This does no checking.

    $writer->delete_field_from_file(filename=>$filename,field=>$field);

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

    $writer->replace_all_meta(filename=>$filename,meta=>\%meta);

=cut

sub replace_all_meta {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $meta = $args{meta};
    my $et = new Image::ExifTool;
    $et->Options(ListSep=>',',ListSplit=>',');
    $et->ExtractInfo($filename);

    $self->_write_meta(filename=>$filename,meta=>$meta);
    
} # replace_all_meta

=head2 replace_one_field

Overwrite the given field. This does no checking.

    $writer->replace_one_field(filename=>$filename,field=>$field,value=>$value);

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

    my $filename = $args{filename};
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

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer::Gif
__END__
