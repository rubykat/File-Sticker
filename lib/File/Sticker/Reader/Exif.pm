package File::Sticker::Reader::Exif;

=head1 NAME

File::Sticker::Reader::Exif - read and standardize meta-data from EXIF file

=head1 SYNOPSIS

    use File::Sticker::Reader::Exif;

    my $obj = File::Sticker::Reader::Exif->new(%args);

    my %meta = $obj->read_meta(%args);

=head1 DESCRIPTION

This will read meta-data from EXIF files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use Image::ExifTool qw(:Public);

use parent qw(File::Sticker::Reader);

=head1 METHODS

=head2 allowed_file

If this reader can be used for the given file, then this returns true.
File must be one of: an image, PDF, or EPUB.

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} =~ /(image|pdf|epub)/)
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
        url=>1,
        creator=>1,
        title=>1,
        description=>1,
        tags=>1};
} # known_fields

=head2 read_meta

Read the meta-data from the given file.

    my %meta = $obj->read_meta(filename=>$filename);

=cut

sub read_meta {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};

    my $info = ImageInfo($filename);
    my %meta = ();
    my $is_gutenberg_book = 0;
    if ($info->{'Identifier'} =~ m!http://www.gutenberg.org/ebooks/\d+!)
    {
        $is_gutenberg_book = 1;
    }
    foreach my $key (sort keys %{$info})
    {
        my $val = $info->{$key};
        if ($val)
        {
            if ($key eq 'Source')
            {
                $meta{'url'} = $val;
                if ($info->{'Identifier'} =~ m!http://www.gutenberg.org/ebooks/\d+!)
                {
                    # the gutenberg identifier is better than the gutenberg source
                    $meta{'url'} = $info->{'Identifier'};
                }
            }
            elsif ($key =~ /creator|artist|author/i)
            {
                $meta{'creator'} = $val;
            }
            elsif ($key eq 'Title')
            {
                $meta{'title'} = $val;
            }
            elsif ($key =~ /comment|description/i)
            {
                $meta{'description'} = $val;
            }
            elsif ($key eq 'Keywords' or $key eq 'Subject')
            {
                my @tags;
                if ($is_gutenberg_book)
                {
                    # gutenberg tags are multi-word, separated by comma-space or ' -- '
                    # and can have parens in them
                    $val =~ s/\(//g;
                    $val =~ s/\)//g;
                    $val =~ s/\s--\s/,/g;
                    @tags = split(/,\s?/, $val);
                }

                if ($meta{tags})
                {
                    push @tags, split(/,/, $meta{tags}); # don't forget previous ones
                }
                my %tagdup = (); # remove any duplicates
                foreach my $t (@tags)
                {
                    if ($t)
                    {
                        $tagdup{$t}++;
                    }
                }
                $meta{'tags'} = join(',', sort keys %tagdup);
            }
        } # if $val
    } # for each key

    return %meta;
} # read_meta

=cut

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Reader
__END__
