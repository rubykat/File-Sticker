package File::Sticker::Writer::Xattr;

=head1 NAME

File::Sticker::Writer::Xattr - write and standardize meta-data from ExtAttr file

=head1 SYNOPSIS

    use File::Sticker::Writer::Xattr;

    my $obj = File::Sticker::Writer::Xattr->new(%args);

    my %meta = $obj->write_meta(%args);

=head1 DESCRIPTION

This will write meta-data from extended user attributes of files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use File::ExtAttr ':all';
use File::Basename;
use String::CamelCase qw(wordsplit);

use parent qw(File::Sticker::Writer);

=head1 METHODS

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
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

=head1 Helper Functions

Private interface.

=cut

=head2 replace_one_field

Overwrite the given field. This does no checking.

    $writer->replace_one_field(filename=>$filename,field=>$field,value=>$value);

=cut

sub replace_one_field {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};
    my $fname = $args{field};
    my $value = $args{value};

    if (-w $filename)
    {
        setfattr($filename, $fname, $value);
    }
} # replace_one_field

=head2 delete_one_field

Completely remove the given field. This does no checking.

    $writer->delete_one_field(filename=>$filename,field=>$field);

=cut

sub delete_one_field {
    my $self = shift;
    my %args = @_;
    my $filename = $args{filename};
    my $field = $args{field};

    if (-w $filename)
    {
        delfattr($filename, $field);
    }
} # delete_one_field

=head2 add_field_to_file

Add a general field to a file

    $writer->add_field_to_file(filename=>$filename,
        value=>$value,
        field=>$field_name);
=cut
sub add_field_to_file ($%) {
    my $self = shift;
    my %args = @_;
    my $filename = $args{path};
    my $field = $args{field};
    my $value = $args{value};

    if ($field eq 'tags' or $field eq 'private_tags')
    {
        # replace undesirable characters in tag values
        $value =~ s/[:.]/-/g;
        my $prefix = '';
        if ($value =~ /^([=-])(.*)/)
        {
            $prefix = $1;
            $value = $2;
        }
        if ($prefix eq '=')
        {
            # use tags==val to reset the tags
            setfattr($filename, $field, $value);
        }
        else
        {
            # allow for multiple values, comma-separated
            my @vals = ($value);
            if ($value =~ /,/)
            {
                @vals = split(/,/, $value);
            }
            foreach my $v (@vals)
            {
                if ($prefix eq '-')
                {
                    $self->delete_multival_from_file(
                        filename=>$filename,
                        name=>$field,
                        value=>$v);
                }
                else
                {
                    $self->add_multival_to_file(
                        filename=>$filename,
                        name=>$field,
                        value=>$v);
                }
            }
        }
    }
    elsif ($field eq 'url')
    {
        setfattr($filename, 'dublincore.source', $value);
    }
    elsif ($field eq 'title')
    {
        if (!$value and $self->{derive})
        {
            $value = $self->derive_title($filename);
        }
        setfattr($filename, 'dublincore.title', $value);
    }
    elsif ($field eq 'description')
    {
        setfattr($filename, 'dublincore.description', $value);
    }
    else
    {
        setfattr($filename, $field, $value);
    }

} # add_field_to_file

=head2 delete_field_from_file

Delete a whole field.

    $writer->delete_field_from_file(filename=>$filename,
        field=>$field_name);

=cut
sub delete_field_from_file ($%) {
    my $self = shift;
    my %args = @_;
    my $filename = $args{filename};
    my $field = $args{field};

    if ($field eq 'tag')
    {
        delfattr($filename, 'tags');
    }
    if ($field eq 'url')
    {
        delfattr($filename, 'dublincore.source');
    }
    elsif ($field eq 'title')
    {
        delfattr($filename, 'dublincore.title');
    }
    elsif ($field eq 'description')
    {
        delfattr($filename, 'dublincore.description');
    }
    elsif ($field eq 'thumb_ext')
    {
        delfattr($filename, 'xfile.thumb_ext');
    }
    else
    {
        delfattr($filename, $field);
    }

} # delete_field_from_file

=head2 derive_title

Derive the title from the filename.

    my $title = $writer->derive_title($filename);

=cut
sub derive_title($$) {
    my $self = shift;
    my $filename = shift;

    my ($bn, $path, $suffix) = fileparse($filename, qr/\.[^.]*/);
    my @words = wordsplit($bn);
    my $title = join(' ', @words);
    $title =~ s/(\w+)/\u\L$1/g; # title case
    $title =~ s/(\d+)$/ $1/; # trailing numbers
    return $title;
} # derive_title

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
