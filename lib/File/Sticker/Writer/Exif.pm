package File::Sticker::Writer::Exif;

=head1 NAME

File::Sticker::Writer::Exif - write and standardize meta-data from EXIF file

=head1 SYNOPSIS

    use File::Sticker::Writer::Exif;

    my $obj = File::Sticker::Writer::Exif->new(%args);

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
    return 1;
} # priority

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
File must be one of: PDF or an image which is not a GIF.
(GIF files need to be treated separately)
(ExifTool can't write to EPUB)

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;
    say STDERR whoami(), " file=$file" if $self->{verbose} > 2;

    $file = $self->_get_the_real_file(filename=>$file);
    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} =~ /(image|pdf)/
            and $ft->{mime_type} !~ /gif/)
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this writer knows about.

    my $known_fields = $writer->known_fields();

=cut

sub known_fields {
    my $self = shift;

    return {
        title=>'TEXT',
        creator=>'TEXT',
        description=>'TEXT',
        location=>'TEXT',
        tags=>'MULTI',
        %{$self->{wanted_fields}},
    };
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
        copyright=>'TEXT',
        flash=>'TEXT',
        imagesize=>'TEXT',
        imageheight=>'NUMBER',
        imagewidth=>'NUMBER',
        megapixels=>'NUMBER'};
} # readonly_fields

=head1 Helper Functions

Private interface.

=head2 replace_one_field

Overwrite the given field. This does no checking.

    $writer->replace_one_field(filename=>$filename,field=>$field,value=>$value);

=cut

sub replace_one_field {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " field=$args{field},value=$args{value}" if $self->{verbose} > 2;

    my $filename = $self->_get_the_real_file(filename=>$args{filename});
    my $field = $args{field};
    my $value = $args{value};

    my $ft = $self->{file_magic}->info_from_filename($filename);
    my $et = new Image::ExifTool;
    $et->Options(ListSep=>',',ListSplit=>',');
    $et->ExtractInfo($filename);

    my $success;
    if ($field eq 'creator')
    {
        $success = $et->SetNewValue('Creator', $value);
    }
    elsif ($field eq 'copyright')
    {
        $success = $et->SetNewValue('License', $value);
    }
    elsif ($field eq 'title')
    {
        $success = $et->SetNewValue('Title', $value);
    }
    elsif ($field eq 'location')
    {
        $success = $et->SetNewValue('Location', $value);
    }
    elsif ($field eq 'description')
    {
        # We need to make sure that the UserComment contains
        # the description and NOT the freeform data
        # because GIMP expects the UserComment to contain
        # the image comment (and DOES NOT LOOK in the Comment field)
        if ($self->_convert_freeform_data(exif=>$et))
        {
            $success = $et->SetNewValue('UserComment', $value);
        }
        
        if ($ft->{mime_type} =~ /image\/jpeg/)
        {
            $success = $et->SetNewValue('Comment', $value);
        }
        $success = $et->SetNewValue('Description', $value);
    }
    elsif ($field eq 'tags')
    {
        if (ref $value eq 'ARRAY')
        {
            $success = $et->SetNewValue('Keywords', $value);
            $success = $et->SetNewValue('Subject', $value);
        }
        else
        {
            my @tags = split(/,/,$value);
            $success = $et->SetNewValue('Keywords', \@tags);
            $success = $et->SetNewValue('Subject', \@tags);
        }
    }
    else # freeform field
    {
        # Need to read all the YAML, change this field, and write it again
        my $fdata = $self->_read_freeform_data(exif=>$et);
        $fdata->{$field} = $value;
        $success = $self->_write_freeform_data(newdata=>$fdata,exif=>$et);
    }

    if ($success)
    {
        $et->WriteInfo($filename);
    }
    return $success;
} # replace_one_field

=head2 delete_field_from_file

Completely remove the given field. This does no checking.

    $writer->delete_field_from_file(filename=>$filename,field=>$field);

=cut

sub delete_field_from_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " field=$args{field}" if $self->{verbose} > 2;

    my $filename = $self->_get_the_real_file(filename=>$args{filename});
    my $field = $args{field};

    my $ft = $self->{file_magic}->info_from_filename($filename);
    my $et = new Image::ExifTool;
    $et->Options(ListSep=>',',ListSplit=>',');
    $et->ExtractInfo($filename);

    my $success;
    if ($field eq 'creator')
    {
        $success = $et->SetNewValue('Creator')
    }
    elsif ($field eq 'title')
    {
        $success = $et->SetNewValue('Title')
    }
    elsif ($field eq 'description')
    {
        if ($ft->{mime_type} =~ /image\/jpeg/)
        {
            $success = $et->SetNewValue('Comment');
        }
        $success = $et->SetNewValue('Description');
    }
    elsif ($field eq 'tags')
    {
        $success = $et->SetNewValue('Keywords');
        $success = $et->SetNewValue('Subject');
    }
    else # freeform field
    {
        # Need to read all the YAML, change this field, and write it again
        my $fdata = $self->_read_freeform_data(exif=>$et);
        if (exists $fdata->{$field})
        {
            delete $fdata->{$field};
            $success = $self->_write_freeform_data(newdata=>$fdata,exif=>$et);
        }
    }

    if ($success)
    {
        $et->WriteInfo($filename);
    }
    return $success;
} # delete_field_from_file

=head2 _get_the_real_file

If the file is a directory, look for a cover file.

    my $real_file = $writer->_get_the_real_file(filename=>$filename);

=cut

sub _get_the_real_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    if (-d $filename) # is a directory, look for a cover file
    {
        my $cover_file = ($self->{cover_file} ? $self->{cover_file} : 'cover.jpg');
        $cover_file = File::Spec->catfile($filename, $cover_file);
        if (-f $cover_file)
        {
            $filename = $cover_file;
        }
    }
    return $filename;
} # _get_the_real_file

=head2 _read_freeform_data

Read the freeform data as YAML data from the ImageDescription field.
 
    my $ydata = $self->_read_freeform_data(exif=>$exif);

=cut

sub _read_freeform_data {
    my $self = shift;
    my %args = @_;
    say STDERR whoami() if $self->{verbose} > 2;

    # CONVERT FREEFORM DATA if needed BEFOREHAND
    $self->_convert_freeform_data(%args);

    my $ydata;
    my $et = $args{exif};
    my $ystring = $et->GetValue('ImageDescription');
    $ystring = $et->GetNewValue('ImageDescription') if !$ystring;
    say STDERR "ystring=$ystring" if $self->{verbose} > 2;
    if ($ystring)
    {
        eval {$ydata = Load($ystring);};
        if ($@)
        {
            warn __PACKAGE__, " Load of YAML data failed: $@";
        }
        elsif (!$ydata)
        {
            warn __PACKAGE__, " no legal YAML" if $self->{verbose} > 1;
        }
    }
    say STDERR Dump($ydata) if $self->{verbose} > 2;
    return $ydata;
} # _read_freeform_data

=head2 _write_freeform_data

Write the freeform data as YAML data into the ImageDescription field
This overwrites whatever is there, it does not check.
    
    $self->_write_freeform_data(newdata=>\%newdata,exif=>$exif);

=cut

sub _write_freeform_data {
    my $self = shift;
    my %args = @_;
    say STDERR whoami() if $self->{verbose} > 2;

    my $newdata = $args{newdata};
    my $et = $args{exif};
    # restore multi-value comma-separated fields to arrays
    foreach my $fn (keys %{$self->{wanted_fields}})
    {
        if ($self->{wanted_fields}->{$fn} eq 'MULTI'
                and exists $newdata->{$fn}
                and defined $newdata->{$fn}
                and $newdata->{$fn} =~ /,/)
        {
            my @vals = split(/,/, $newdata->{$fn});
            $newdata->{$fn} = \@vals;
        }
    }
    my $ystring = Dump($newdata);
    say STDERR "ystring=$ystring" if $self->{verbose} > 2;
    my $success = $et->SetNewValue('ImageDescription', $ystring);
    return $success;
} # _write_freeform_data

=head2 _convert_freeform_data

Convert the freeform data so that it is placed into
the ImageDescription field rather than the UserComment field,
and put the "description" info into the UserComment field,
so that GIMP will not use the freeform data as the image comment!
    
    $self->_convert_freeform_data(exif=>$exif);

=cut

sub _convert_freeform_data {
    my $self = shift;
    my %args = @_;
    say STDERR whoami() if $self->{verbose} > 2;

    my $et = $args{exif};
    # Check if it needs conversion at all.
    # If the ImageDescription field is not empty
    # and contains YAML data, then nothing needs to be done.
    my $ystring = $et->GetValue('ImageDescription');
    $ystring = $et->GetNewValue('ImageDescription') if !$ystring;
    if ($ystring and $ystring =~ /^---/) # Assume YAML data
    {
        # no conversion needed
        return 1;
    }

    # ------------------------------------
    # Conversion needed
    # Read from UserComment, write into ImageDescription
    # ------------------------------------
    $ystring = $et->GetValue('UserComment') if !$ystring;
    $ystring = $et->GetNewValue('UserComment') if !$ystring;
    my $ydata;
    my $success = 0;
    if ($ystring and $ystring =~ /^---/) # Probably YAML data
    {
        eval {$ydata = Load($ystring);};
        if ($@)
        {
            warn __PACKAGE__, " Load of YAML data failed: $@";
        }
        elsif (!$ydata)
        {
            warn __PACKAGE__, " no legal YAML" if $self->{verbose} > 1;
        }
        else # data is okay
        {
            $success = $et->SetNewValue('ImageDescription', $ystring);
            if ($success)
            {
                # Also clear out UserComment from no longer valid data
                $et->SetNewValue('UserComment');

                # Put the description into the UserComment if there is one
                my $desc = $et->GetValue('Comment');
                $desc = $et->GetNewValue('Comment') if !$desc;
                $desc = $et->GetValue('Description') if !$desc;
                $desc = $et->GetNewValue('Description') if !$desc;
                $desc = $et->GetValue('Caption-Abstract') if !$desc;
                $et->SetNewValue('UserComment', $desc) if $desc;
            }
        }
    }
    else # No YAML data to convert
    {
        # Put some empty data in there.
        my %newdata = ();
        my $nystring = Dump(\%newdata);
        $success = $et->SetNewValue('ImageDescription', $nystring);
    }

    return $success;
} # _convert_freeform_data

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
