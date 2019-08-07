import React from 'react';
import {
  List,
  Edit,
  Create,
  Datagrid,
  BooleanField,
  TextField,
  DateField,
  NumberField,
  SimpleForm,
  NumberInput,
  TextInput,
  SelectInput,
  BooleanInput,
  DateInput,
} from 'react-admin';

const coin_choices = [
  { id: "BTC", name: "Bitcoin"},
  { id: "BCH", name: "Bitcoin Cash"},
  { id: "BSV", name: "Bitcoin SV"}
]

const client_choices = [
    { id: "core", name: "Bitcoin Core"},
    { id: "bcoin", name: "bcoin"},
    { id: "knots", name: "Knots"},
    { id: "btcd", name: "Btcd"},
    { id: "libbitcoin", name: "libbitcoin"},
    { id: "abc", name: "Bitcoin ABC"},
    { id: "sv", name: "Bitcoin SV"},
    { id: "bu", name: "Bitcoin Unlimited"},
];

export const NodeList = props => (
    <List {...props}
        sort={{ field: "id"}}
        >
        <Datagrid rowClick="edit">
            <NumberField source="id" />
            <TextField source="coin" />
            <TextField source="name_with_version" />
            <DateField source="unreachable_since" />
        </Datagrid>
    </List>
);

export const NodeEdit = props => (
    <Edit {...props}>
        <SimpleForm>
            <TextField source="coin" />
            <TextField source="name_with_version" readOnly />
            <TextInput source="version_extra" />
            <TextInput source="rpchost" />
            <NumberInput source="rpcport" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
            <BooleanInput source="pruned" />
            <TextInput source="os" />
            <TextInput source="cpu" />
            <NumberInput source="ram" />
            <TextInput source="storage" />
            <BooleanInput source="cve_2018_17144" />
            <DateInput source="released" />
        </SimpleForm>
    </Edit>
);

export const NodeCreate = props => (
    <Create {...props}>
        <SimpleForm>
            <SelectInput source="coin" defaultValue="BTC" choices={ coin_choices } />
            <TextInput source="name" defaultValue="Bitcoin Core" />
            <SelectInput source="client_type" defaultValue="core" choices={ client_choices } />
            <TextInput source="version_extra" />
            <TextInput source="rpchost" />
            <NumberInput source="rpcport" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
            <BooleanInput source="pruned" />
            <TextInput source="os" />
            <TextInput source="cpu" />
            <NumberInput source="ram" />
            <TextInput source="storage" />
            <BooleanInput source="cve_2018_17144" />
            <DateInput source="released" />
        </SimpleForm>
    </Create>
);
