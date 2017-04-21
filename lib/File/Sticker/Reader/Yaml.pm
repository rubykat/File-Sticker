package File::Sticker::Reader::Yaml;

=head1 NAME

File::Sticker::Reader::Yaml - read and standardize meta-data from YAML file

=head1 SYNOPSIS

    use File::Sticker::Reader::Yaml;

    my $obj = File::Sticker::Reader::Yaml->new(%args);

    my %meta = $obj->read_meta(%args);

=head1 DESCRIPTION

This will read meta-data from YAML files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use YAML::Any qw(Dump LoadFile);

use parent qw(File::Sticker::Reader);

=head1 METHODS

=head2 allowed_file

If this reader can be used for the given file, then this returns true.
File must be plain text and end with '.yml'

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} eq 'text/plain'
            and $file =~ /\.yml$/)
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

    my %meta = $obj->read_meta(filename=>$filename);

=cut

sub read_meta {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};

    my ($info) = LoadFile($filename);
    my %meta = ();
    foreach my $key (sort keys %{$info})
    {
        my $val = $info->{$key};
        if ($val)
        {
            if ($key eq 'tags')
            {
                $meta{tags} = $val;
                $meta{tags} =~ s/ /,/g; # spaces to commas
            }
            elsif ($key eq 'dublincore.source')
            {
                $meta{'url'} = $val;
            }
            elsif ($key eq 'dublincore.title')
            {
                $meta{'title'} = $val;
            }
            elsif ($key eq 'dublincore.creator')
            {
                $meta{'creator'} = $val;
            }
            elsif ($key eq 'dublincore.description')
            {
                $meta{'description'} = $val;
            }
            elsif ($key eq 'private')
            {
                # deal with this after tags
            }
            else
            {
                $meta{$key} = $val;
            }
        }
    }
    if ($info->{private})
    {
        $meta{tags} .= ",private";
    }
    return %meta;
} # read_meta

=cut

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Reader
__END__
