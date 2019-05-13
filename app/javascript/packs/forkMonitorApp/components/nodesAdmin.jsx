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
  SelectInput
} from 'react-admin';

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
            <TextField source="client_type" />
            <TextField source="name"/>
            <TextField source="version" />
            <DateField source="unreachable_since" />
            <NumberField source="best_block.height" />
        </Datagrid>
    </List>
);

export const NodeEdit = props => (
    <Edit {...props}>
        <SimpleForm>
            <TextInput source="coin" defaultValue="BTC"  />
            <TextInput source="name" />
            <SelectInput source="client_type" choices={ client_choices } />
            <TextInput source="rpchost" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
        </SimpleForm>
    </Edit>
);

export const NodeCreate = props => (
    <Create {...props}>
        <SimpleForm>
            <TextInput source="coin" />
            <TextInput source="name" defaultValue="Bitcoin Core" />
            <SelectInput source="client_type" defaultValue="core" choices={ client_choices } />
            <TextInput source="rpchost" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
        </SimpleForm>
    </Create>
);
